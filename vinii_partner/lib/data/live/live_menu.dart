import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/failure.dart';
import '../../domain/menu.dart';
import '../backend.dart';
import 'errors.dart';
import 'live_backend.dart';

/// The POS Item Master: `menu_categories`, `menu_items`, photos in the public
/// `item-images` bucket. Every query names the organization explicitly.
///
/// Writes go straight to these tables, which the database allows for any
/// member today. The app limits them to owners, admins and managers until
/// the database checks roles itself (contract R4, gap G2).
class LiveMenu implements MenuRepository {
  LiveMenu(this.b);
  final LiveBackend b;

  static const _itemColumns =
      'id, category_id, name, price, description, image_url, food_type, course, is_available, is_recommended, prep_minutes, sort_order';

  @override
  Future<MenuSnapshot> load() async {
    final orgId = b.org.id;
    try {
      final results = await Future.wait([
        b.client
            .from('menu_categories')
            .select('id, name, sort_order')
            .eq('organization_id', orgId)
            .order('sort_order', ascending: true),
        b.client
            .from('menu_items')
            .select(_itemColumns)
            .eq('organization_id', orgId)
            .order('sort_order', ascending: true)
            .order('name', ascending: true),
      ]);
      return MenuSnapshot(
        categories: [for (final r in results[0]) _category(r)],
        items: [for (final r in results[1]) _item(r)],
      );
    } catch (e) {
      throw fromSupabase(e);
    }
  }

  @override
  Future<MenuCategory> saveCategory(
    MenuCategory category, {
    required bool isNew,
  }) async {
    final name = category.name.trim();
    if (name.isEmpty) {
      throw const AppFailure(
        'Give the category a name.',
        kind: FailureKind.rejected,
        code: 'menu_category_name_needed',
      );
    }
    try {
      final row = isNew
          ? await b.client
                .from('menu_categories')
                .insert({
                  'organization_id': b.org.id,
                  'name': name,
                  'sort_order': category.sortOrder,
                })
                .select('id, name, sort_order')
                .single()
          : await b.client
                .from('menu_categories')
                .update({'name': name, 'sort_order': category.sortOrder})
                .eq('id', category.id)
                .eq('organization_id', b.org.id)
                .select('id, name, sort_order')
                .single();
      return _category(row);
    } catch (e) {
      throw fromSupabase(e);
    }
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    try {
      // Items keep existing; the foreign key sets their category to null.
      final gone = await b.client
          .from('menu_categories')
          .delete()
          .eq('id', categoryId)
          .eq('organization_id', b.org.id)
          .select('id');
      if (gone.isEmpty) {
        throw const AppFailure(
          'That category could not be removed. It may already be gone.',
          kind: FailureKind.rejected,
          code: 'menu_category_not_removed',
        );
      }
    } catch (e) {
      throw fromSupabase(e);
    }
  }

  @override
  Future<void> reorderCategories(List<String> categoryIdsInOrder) async {
    try {
      for (var i = 0; i < categoryIdsInOrder.length; i++) {
        await b.client
            .from('menu_categories')
            .update({'sort_order': i + 1})
            .eq('id', categoryIdsInOrder[i])
            .eq('organization_id', b.org.id);
      }
    } catch (e) {
      throw fromSupabase(e);
    }
  }

  @override
  Future<MenuItem> saveItem(MenuItem item, {required bool isNew}) async {
    final name = item.name.trim();
    if (name.isEmpty) {
      throw const AppFailure(
        'Give the item a name.',
        kind: FailureKind.rejected,
        code: 'menu_item_name_needed',
      );
    }
    if (item.price < 0) {
      throw const AppFailure(
        'Price cannot be negative.',
        kind: FailureKind.rejected,
        code: 'menu_price_negative',
      );
    }
    final values = {
      'category_id': item.categoryId,
      'name': name,
      'price': item.price,
      'description': (item.description?.trim().isEmpty ?? true)
          ? null
          : item.description!.trim(),
      'image_url': item.imageUrl,
      'food_type': item.foodType?.dbValue,
      'course': item.course,
      'is_available': item.isAvailable,
      'is_recommended': item.isRecommended,
      'prep_minutes': item.prepMinutes,
      'sort_order': item.sortOrder,
    };
    try {
      final row = isNew
          ? await b.client
                .from('menu_items')
                .insert({...values, 'organization_id': b.org.id})
                .select(_itemColumns)
                .single()
          : await b.client
                .from('menu_items')
                .update(values)
                .eq('id', item.id)
                .eq('organization_id', b.org.id)
                .select(_itemColumns)
                .single();
      return _item(row);
    } catch (e) {
      throw fromSupabase(e);
    }
  }

  @override
  Future<void> setItemAvailable(String itemId, bool available) async {
    try {
      final changed = await b.client
          .from('menu_items')
          .update({'is_available': available})
          .eq('id', itemId)
          .eq('organization_id', b.org.id)
          .select('id');
      if (changed.isEmpty) {
        throw const AppFailure(
          'That item no longer exists.',
          kind: FailureKind.rejected,
          code: 'menu_item_gone',
        );
      }
    } catch (e) {
      throw fromSupabase(e);
    }
  }

  @override
  Future<String> uploadItemImage(
    String itemId,
    Uint8List bytes, {
    required String extension,
  }) async {
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      throw const AppFailure(
        'That photo is too large. Choose one under 5 MB.',
        kind: FailureKind.rejected,
        code: 'photo_too_large',
      );
    }
    final ext = extension.toLowerCase().replaceAll('.', '');
    final type = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    // Organization folder first, so photos can be scoped per organization
    // by storage policy later. A new file per upload: a CDN never serves a
    // stale photo, and the old one stays until someone cleans up.
    final path =
        '${b.org.id}/$itemId-${DateTime.now().millisecondsSinceEpoch}.${ext == 'jpg' ? 'jpeg' : ext}';
    try {
      final bucket = b.client.storage.from('item-images');
      await bucket.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: type, upsert: false),
      );
      return bucket.getPublicUrl(path);
    } catch (e) {
      throw fromSupabase(e);
    }
  }

  MenuCategory _category(Map<String, dynamic> r) => MenuCategory(
    id: '${r['id']}',
    name: '${r['name']}',
    sortOrder: (r['sort_order'] as num?)?.toInt() ?? 0,
  );

  MenuItem _item(Map<String, dynamic> r) => MenuItem(
    id: '${r['id']}',
    categoryId: r['category_id'] as String?,
    name: '${r['name']}',
    price: double.tryParse('${r['price']}') ?? 0,
    description: r['description'] as String?,
    imageUrl: (r['image_url'] as String?)?.trim().isEmpty ?? true
        ? null
        : r['image_url'] as String,
    foodType: FoodType.fromDb(r['food_type'] as String?),
    course: (r['course'] as String?) ?? 'eat',
    isAvailable: r['is_available'] != false,
    isRecommended: r['is_recommended'] == true,
    prepMinutes: (r['prep_minutes'] as num?)?.toInt(),
    sortOrder: (r['sort_order'] as num?)?.toInt() ?? 0,
  );
}
