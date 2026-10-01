import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money.dart';
import '../../domain/billing.dart';
import '../theme/guest_theme.dart';
import '../widgets/food_art.dart';
import 'guest_flow.dart';
import 'guest_widgets.dart';
import 'look/motion.dart';

/// Board 1 #2: "Dining with friends?" — an optional table budget and, when
/// the storefront allows it, how many people share it. Shown only when
/// `features.budget.enabled`; "Skip" leaves the party with no budget at all
/// (no rings anywhere).
class GuestBudgetScreen extends StatefulWidget {
  const GuestBudgetScreen({super.key});

  @override
  State<GuestBudgetScreen> createState() => _GuestBudgetScreenState();
}

class _GuestBudgetScreenState extends State<GuestBudgetScreen> {
  late double _amount;
  late int _people;

  @override
  void initState() {
    super.initState();
    final s = GuestScope.read(context);
    final b = s.features.budget;
    _amount = (s.budget ?? b.defaultAmount.toDouble())
        .clamp(b.min.toDouble(), b.max.toDouble())
        .toDouble();
    _people = s.partySize;
  }

  void _done({required bool save}) {
    final s = GuestScope.read(context);
    s.update(() {
      s.budgetAsked = true;
      s.budget = save ? _amount : null;
      s.partySize = _people;
    });
    GuestFlow.toCategories(context);
  }

  Future<void> _edit() async {
    final p = GuestPalette.of(context);
    final b = GuestScope.read(context).features.budget;
    final ctl = TextEditingController(text: _amount.round().toString());
    final v = await showDialog<double>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        backgroundColor: p.surface,
        title: Text('Total budget', style: p.display(20)),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            prefixText: '₹ ',
            helperText: '${rupees(b.min)} – ${rupees(b.max)}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: p.body(15)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(double.tryParse(ctl.text)),
            child: Text('Set', style: p.body(15, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (v != null && mounted) {
      setState(
        () => _amount = v.clamp(b.min.toDouble(), b.max.toDouble()).toDouble(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final t = GuestCopy.of(context);
    final b = s.features.budget;
    final divisions = ((b.max - b.min) / b.step).round();
    return GuestPage(
      bottom: GuestButton(
        label: t('budget.cta'),
        onTap: () => _done(save: true),
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GuestTopBar(
            trailing: [
              TextButton(
                onPressed: () => _done(save: false),
                child: Text(
                  'Skip',
                  style: p.body(15, weight: FontWeight.w700, color: p.inkMuted),
                ),
              ),
            ],
          ),
          Reveal(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Text(t('budget.title'), style: p.display(30)),
            ),
          ),
          Reveal(
            index: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Text(
                t('budget.subtitle'),
                style: p.body(15, color: p.inkMuted),
              ),
            ),
          ),
          Reveal(
            index: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GuestCard(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total budget', style: p.body(14, color: p.inkMuted)),
                    Row(
                      children: [
                        Expanded(
                          child: CountUp(
                            value: _amount,
                            format: rupees,
                            duration: GuestMotion.base,
                            style: p.price(36),
                          ),
                        ),
                        RoundIcon(
                          icon: Icons.edit_outlined,
                          size: 40,
                          tooltip: 'Type an amount',
                          onTap: _edit,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _amount,
                      min: b.min.toDouble(),
                      max: b.max.toDouble(),
                      divisions: divisions > 0 ? divisions : null,
                      onChanged: (v) {
                        HapticFeedback.selectionClick();
                        setState(() => _amount = v);
                      },
                    ),
                    Row(
                      children: [
                        Text(
                          rupees(b.min),
                          style: p.body(12, color: p.inkMuted),
                        ),
                        const Spacer(),
                        Text(
                          rupees(b.max),
                          style: p.body(12, color: p.inkMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (s.features.splitParty) ...[
            const SizedBox(height: 16),
            Reveal(
              index: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GuestCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Split between',
                        style: p.body(14, color: p.inkMuted),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _Avatars(count: _people),
                          const Spacer(),
                          QtyStepper(
                            qty: _people,
                            min: 1,
                            onChanged: (v) =>
                                setState(() => _people = v.clamp(1, 30)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CountUp(
                        value: BudgetStatus(
                          budget: _amount,
                          spent: 0,
                        ).perPerson(_people).roundToDouble(),
                        duration: GuestMotion.base,
                        format: (v) =>
                            '$_people ${_people == 1 ? 'person' : 'people'}  ·  '
                            '${rupees(v)} per person',
                        style: p.body(14, weight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Overlapping person circles, "+3" after four.
class _Avatars extends StatelessWidget {
  const _Avatars({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final shown = count.clamp(1, 4);
    final tones = [p.accent, p.success, const Color(0xFF60A5FA), p.danger];
    return SizedBox(
      height: 38,
      width: 38 + (shown - 1) * 24 + (count > 4 ? 30 : 0),
      child: Stack(
        children: [
          for (var i = 0; i < shown; i++)
            Positioned(
              key: ValueKey('avatar-$i'),
              left: i * 24.0,
              child: _Pop(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tones[i].withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    border: Border.all(color: p.surface, width: 2.5),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (count > 4)
            Positioned(
              left: shown * 24.0 + 18,
              top: 10,
              child: Text('+${count - 4}', style: p.body(13)),
            ),
        ],
      ),
    );
  }
}

/// Springs in when first built, so a person added to the split arrives.
class _Pop extends StatelessWidget {
  const _Pop({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reducedMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: GuestMotion.slow,
      curve: Curves.easeOutBack,
      builder: (context, v, child) =>
          Transform.scale(scale: v.clamp(0, 1.2), child: child),
      child: child,
    );
  }
}

/// Board 1 #8: the budget at a glance, opened by tapping the ring.
class GuestBudgetOverviewScreen extends StatelessWidget {
  const GuestBudgetOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final status = s.budgetStatus;
    final recent = s.lines.reversed.take(5).toList();
    return GuestPage(
      bottom: GuestButton(
        label: 'View full order',
        trailingArrow: true,
        onTap: () => GuestFlow.toOrder(context),
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const GuestTopBar(title: 'Your budget'),
          const SizedBox(height: 16),
          if (status != null) ...[
            Center(
              child: BudgetRing(status: status, size: 200, fromZero: true),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: rupees(status.spent), style: p.price(26)),
                    TextSpan(
                      text: '  of ${rupees(status.budget)}',
                      style: p.body(16, color: p.inkMuted),
                    ),
                  ],
                ),
              ),
            ),
            if (s.lines.isNotEmpty)
              Center(
                child: Text('Estimated', style: p.body(12, color: p.inkMuted)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: BudgetNote(status: status),
            ),
          ],
          if (recent.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                'Recent additions',
                style: p.display(18, weight: FontWeight.w700),
              ),
            ),
            for (final (n, l) in recent.indexed)
              Reveal(
                index: n,
                dx: 18,
                dy: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 5,
                  ),
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 48,
                        child: FoodArt(
                          name: l.name,
                          imageUrl: s.catalog.item(l.itemId)?.item.imageUrl,
                          radius: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: p.body(15, weight: FontWeight.w600),
                        ),
                      ),
                      Text('×${l.qty}', style: p.body(14, color: p.inkMuted)),
                      const SizedBox(width: 12),
                      Text(rupees(l.lineTotal), style: p.price(15)),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
