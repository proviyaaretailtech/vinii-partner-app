import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// Button: save changes
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Button: dismiss without doing it
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Button: delete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// Button: edit
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// Button: add
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// Button: remove one thing from a list
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// Search field label
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// Filter control
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get commonFilter;

  /// Button: go back
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Button: next step
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// Button: continue
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// Button: finished
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// Button: submit a form
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get commonSubmit;

  /// Button: confirm
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// Button: close
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Button: skip a step
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get commonSkip;

  /// Button: apply a code or filter
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// Button: clear a field or filter
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// Button: reload
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// Button: share
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// Button: copy to clipboard
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// Button: print
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get commonPrint;

  /// Button/label: preview
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get commonPreview;

  /// Button: retry after a failure
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// Shown while something loads
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// Answer: yes
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// Answer: no
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// Button: acknowledge
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// State word of a switch that is on
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get commonOn;

  /// State word of a switch that is off
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get commonOff;

  /// Button: sign in
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get commonSignIn;

  /// Button: sign out
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get commonSignOut;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get commonPassword;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get commonEmail;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get commonPhoneNumber;

  /// Title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// Label for the language setting
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get commonLanguage;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonName;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get commonAddress;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get commonStatus;

  /// Label of a total amount
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get commonTotal;

  /// Label of a subtotal
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get commonSubtotal;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get commonAmount;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get commonQuantity;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get commonPrice;

  /// Field label for free-text notes
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get commonNotes;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get commonReason;

  /// Marks a mandatory field
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get commonRequired;

  /// Marks an optional field
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get commonOptional;

  /// State: active
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get commonActive;

  /// State: inactive
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get commonInactive;

  /// State: not yet published
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get commonDraft;

  /// State: published
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get commonPublished;

  /// State: waiting
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get commonPending;

  /// State: suspended
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get commonSuspended;

  /// Filter: everything
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// Nothing selected
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// Day word
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// Day word: the day before today
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get commonYesterday;

  /// Connection state
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get commonOffline;

  /// Connection state
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get commonOnline;

  /// Title of the More tab
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get commonMore;

  /// Word: order
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get commonOrder;

  /// Word: orders / tab title
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get commonOrders;

  /// Word: menu / tab title
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get commonMenu;

  /// Word: table
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get commonTable;

  /// Word: bill
  ///
  /// In en, this message translates to:
  /// **'Bill'**
  String get commonBill;

  /// Word: payment
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get commonPayment;

  /// Word: discount
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get commonDiscount;

  /// Word: customer
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get commonCustomer;

  /// Word: item
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get commonItem;

  /// Word: category
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get commonCategory;

  /// Offline notice
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get commonNoInternet;

  /// Generic failure sentence
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get commonSomethingWrong;

  /// POS order status code 'new'
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get statusNew;

  /// POS order status code 'in_billing'
  ///
  /// In en, this message translates to:
  /// **'In billing'**
  String get statusInBilling;

  /// POS order status code 'sent_to_kitchen'
  ///
  /// In en, this message translates to:
  /// **'In kitchen'**
  String get statusSentToKitchen;

  /// POS order status code 'ready'
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get statusReady;

  /// POS order status code 'awaiting_payment'
  ///
  /// In en, this message translates to:
  /// **'Awaiting payment'**
  String get statusAwaitingPayment;

  /// POS order status code 'paid'
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get statusPaid;

  /// POS order status code 'delivered' (dine-in: served at the table)
  ///
  /// In en, this message translates to:
  /// **'Served'**
  String get statusServed;

  /// POS order status code 'cancelled'
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// Delivery state 'placed'
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get deliveryStatusPlaced;

  /// Delivery state 'accepted'
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get deliveryStatusAccepted;

  /// Delivery state 'packed'
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get deliveryStatusPacked;

  /// Delivery state 'out'
  ///
  /// In en, this message translates to:
  /// **'Out for delivery'**
  String get deliveryStatusOut;

  /// Delivery state 'delivered'
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get deliveryStatusDelivered;

  /// Delivery state 'cancelled'
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get deliveryStatusCancelled;

  /// Delivery inbox tab: new orders
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get inboxTabNew;

  /// Delivery inbox tab: being prepared
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get inboxTabPreparing;

  /// Delivery inbox tab: ready / out for delivery
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get inboxTabReady;

  /// Delivery inbox tab: finished orders
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get inboxTabPast;

  /// Payment method code 'cash'
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentMethodCash;

  /// Payment method code 'upi' (acronym stays Latin)
  ///
  /// In en, this message translates to:
  /// **'UPI'**
  String get paymentMethodUpi;

  /// Payment method code 'card'
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get paymentMethodCard;

  /// Service type dine_in
  ///
  /// In en, this message translates to:
  /// **'Dine-in'**
  String get serviceDineIn;

  /// Hint under Dine-in
  ///
  /// In en, this message translates to:
  /// **'Served at the table'**
  String get serviceDineInHint;

  /// Service type pickup
  ///
  /// In en, this message translates to:
  /// **'Takeaway'**
  String get serviceTakeaway;

  /// Hint under Takeaway
  ///
  /// In en, this message translates to:
  /// **'Picked up at the counter'**
  String get serviceTakeawayHint;

  /// Service type delivery
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get serviceDelivery;

  /// Hint under Delivery
  ///
  /// In en, this message translates to:
  /// **'Delivered to an address'**
  String get serviceDeliveryHint;

  /// Failure view title for FailureKind.offline
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get failureTitleOffline;

  /// Failure view title for FailureKind.forbidden
  ///
  /// In en, this message translates to:
  /// **'Not allowed'**
  String get failureTitleForbidden;

  /// Failure view title for FailureKind.notReady
  ///
  /// In en, this message translates to:
  /// **'Not available yet'**
  String get failureTitleNotReady;

  /// Failure view title for FailureKind.auth
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get failureTitleAuth;

  /// Failure view title for every other kind
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get failureTitleOther;

  /// Role org_owner
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get roleOrgOwner;

  /// Role org_admin
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleOrgAdmin;

  /// Role manager
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get roleManager;

  /// Role location_manager
  ///
  /// In en, this message translates to:
  /// **'Location manager'**
  String get roleLocationManager;

  /// Role operations_manager
  ///
  /// In en, this message translates to:
  /// **'Operations manager'**
  String get roleOperationsManager;

  /// Role biller (takes payment at the counter)
  ///
  /// In en, this message translates to:
  /// **'Biller'**
  String get roleBiller;

  /// Role captain
  ///
  /// In en, this message translates to:
  /// **'Captain'**
  String get roleCaptain;

  /// Role staff_user
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get roleStaff;

  /// Role kitchen
  ///
  /// In en, this message translates to:
  /// **'KOT / Kitchen'**
  String get roleKitchen;

  /// Role viewer (read only)
  ///
  /// In en, this message translates to:
  /// **'Viewer'**
  String get roleViewer;

  /// Role business_manager
  ///
  /// In en, this message translates to:
  /// **'Business manager'**
  String get roleBusinessManager;

  /// Role finance_manager
  ///
  /// In en, this message translates to:
  /// **'Finance manager'**
  String get roleFinanceManager;

  /// Role accountant
  ///
  /// In en, this message translates to:
  /// **'Accountant'**
  String get roleAccountant;

  /// Role hr_manager
  ///
  /// In en, this message translates to:
  /// **'HR manager'**
  String get roleHrManager;

  /// Role marketing_manager
  ///
  /// In en, this message translates to:
  /// **'Marketing manager'**
  String get roleMarketingManager;

  /// Role inventory_manager
  ///
  /// In en, this message translates to:
  /// **'Inventory manager'**
  String get roleInventoryManager;

  /// Role procurement_manager
  ///
  /// In en, this message translates to:
  /// **'Procurement manager'**
  String get roleProcurementManager;

  /// Role support_user
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get roleSupportUser;

  /// Role analyst
  ///
  /// In en, this message translates to:
  /// **'Analyst'**
  String get roleAnalyst;

  /// Relative time under 45 seconds
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// Relative time in minutes
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String timeMinutesAgo({required int minutes});

  /// Relative time in hours
  ///
  /// In en, this message translates to:
  /// **'{hours} h ago'**
  String timeHoursAgo({required int hours});

  /// Title of the language screen and the settings tile
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// Helper line at the top of the language screen
  ///
  /// In en, this message translates to:
  /// **'Choose the language for this app. It changes everywhere straight away.'**
  String get languageIntro;

  /// Inline progress label on the language tile being switched to
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get languageLoading;

  /// Inline error under a language tile; {language} is its native name
  ///
  /// In en, this message translates to:
  /// **'Could not switch to {language}. Check the connection and try again.'**
  String languageFailed({required String language});

  /// Spoken confirmation after the language switch; {language} is its native name
  ///
  /// In en, this message translates to:
  /// **'Language changed to {language}'**
  String languageChanged({required String language});

  /// Accessibility: the language that is in use
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get languageCurrent;

  /// Subtitle of the Language row in Settings; {language} is the native name
  ///
  /// In en, this message translates to:
  /// **'App language: {language}'**
  String languageSettingsSubtitle({required String language});

  /// Failure code offline
  ///
  /// In en, this message translates to:
  /// **'You are offline. Check the connection and try again.'**
  String get failOffline;

  /// Failure code not_ready: the server lacks a function or table the app needs
  ///
  /// In en, this message translates to:
  /// **'This needs a database update that has not been applied yet.'**
  String get failNotReady;

  /// Failure code permission_denied
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to do that.'**
  String get failPermission;

  /// Failure code already_exists
  ///
  /// In en, this message translates to:
  /// **'That already exists.'**
  String get failAlreadyExists;

  /// Failure code invalid_details
  ///
  /// In en, this message translates to:
  /// **'Some of the details are not valid. Check them and try again.'**
  String get failInvalidDetails;

  /// Failure code record_gone
  ///
  /// In en, this message translates to:
  /// **'That record no longer exists.'**
  String get failRecordGone;

  /// Failure code session_ended
  ///
  /// In en, this message translates to:
  /// **'Your session has ended. Sign in again.'**
  String get failSessionEnded;

  /// Failure code upload_denied
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to upload photos.'**
  String get failUploadDenied;

  /// Failure code photo_too_large
  ///
  /// In en, this message translates to:
  /// **'That photo is too large. Choose one under 5 MB.'**
  String get failPhotoTooLarge;

  /// Failure code bad_credentials
  ///
  /// In en, this message translates to:
  /// **'That email and password do not match. Check them and try again.'**
  String get failBadCredentials;

  /// Failure code email_unconfirmed
  ///
  /// In en, this message translates to:
  /// **'Confirm your email address first. Look for the link in your inbox.'**
  String get failEmailUnconfirmed;

  /// Failure code rate_limited
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a minute and try again.'**
  String get failRateLimited;

  /// Failure code user_banned
  ///
  /// In en, this message translates to:
  /// **'This account has been blocked. Contact your organization admin.'**
  String get failUserBanned;

  /// Failure code sign_in_failed
  ///
  /// In en, this message translates to:
  /// **'Could not sign in. Please try again.'**
  String get failSignInFailed;

  /// Failure code signed_out_elsewhere
  ///
  /// In en, this message translates to:
  /// **'You were signed out. Sign in again to continue.'**
  String get failSignedOutElsewhere;

  /// Failure code choose_org
  ///
  /// In en, this message translates to:
  /// **'Choose an organization first.'**
  String get failChooseOrg;

  /// Failure code build_missing; {settings} is a list of setting names
  ///
  /// In en, this message translates to:
  /// **'This build is missing {settings}.'**
  String failBuildMissing({required String settings});

  /// Server code *_STALE (and *_CONFLICT)
  ///
  /// In en, this message translates to:
  /// **'This was changed on another device. Refresh and try again.'**
  String get failServerStale;

  /// Server code *_NOT_FOUND
  ///
  /// In en, this message translates to:
  /// **'We could not find that. It may have been removed.'**
  String get failServerNotFound;

  /// Server code *_WRONG_STATE
  ///
  /// In en, this message translates to:
  /// **'That cannot be done in its current state.'**
  String get failServerWrongState;

  /// Server code *_FORBIDDEN
  ///
  /// In en, this message translates to:
  /// **'Your role is not allowed to do that.'**
  String get failServerForbidden;

  /// Server code *_BAD_REQUEST and other rejected requests
  ///
  /// In en, this message translates to:
  /// **'Some of the details are not valid. Check them and try again.'**
  String get failServerBadRequest;

  /// Server code *_EXPIRED / *_GONE
  ///
  /// In en, this message translates to:
  /// **'That is no longer open. Refresh and try again.'**
  String get failServerExpired;

  /// Server code *_ITEM_UNAVAILABLE
  ///
  /// In en, this message translates to:
  /// **'One of the items is not available any more.'**
  String get failServerItemUnavailable;

  /// Server code POS_OVERPAY
  ///
  /// In en, this message translates to:
  /// **'That payment is more than the amount due.'**
  String get failServerOverpay;

  /// Server code POS_NOT_PAID_IN_FULL
  ///
  /// In en, this message translates to:
  /// **'The payments do not cover the full total yet.'**
  String get failServerNotPaidInFull;

  /// Server code POS_HAS_PAYMENTS
  ///
  /// In en, this message translates to:
  /// **'Refund the payments before cancelling this order.'**
  String get failServerHasPayments;

  /// Server code POS_EMPTY
  ///
  /// In en, this message translates to:
  /// **'Add between 1 and 50 items to the order.'**
  String get failServerEmpty;

  /// Server code POS_BAD_QTY
  ///
  /// In en, this message translates to:
  /// **'Quantities must be between 1 and 99.'**
  String get failServerBadQty;

  /// Server code POS_BAD_TABLE
  ///
  /// In en, this message translates to:
  /// **'Choose a table for a dine-in order.'**
  String get failServerBadTable;

  /// Server code POS_COUPON_UNKNOWN
  ///
  /// In en, this message translates to:
  /// **'Coupons are not set up for this restaurant.'**
  String get failServerCouponUnknown;

  /// Server code OL_NOT_ACCEPTING
  ///
  /// In en, this message translates to:
  /// **'This restaurant is not taking orders right now.'**
  String get failServerNotAccepting;

  /// Server BAD_REQUEST: a reason is needed (cancel, refund, service charge)
  ///
  /// In en, this message translates to:
  /// **'A reason is needed. Please write one and try again.'**
  String get failServerReasonNeeded;

  /// Server POS_BAD_REQUEST: enter the amount received
  ///
  /// In en, this message translates to:
  /// **'Enter the amount received.'**
  String get failServerAmountReceived;

  /// Sign-in screen: line under the Sign in heading
  ///
  /// In en, this message translates to:
  /// **'Use the email and password you use for the VINII POS.'**
  String get authSignInIntro;

  /// Validation message under the email field when it is empty
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get authEmailRequired;

  /// Validation message under the email field when it is not an address
  ///
  /// In en, this message translates to:
  /// **'That does not look like an email'**
  String get authEmailInvalid;

  /// Validation message under the password field when it is empty
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get authPasswordRequired;

  /// Tooltip of the eye button on the password field (password is hidden)
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// Tooltip of the eye button on the password field (password is visible)
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// Text button on the sign-in screen that opens the password reset screen
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// Small note at the bottom of the sign-in screen (there is no sign-up in the app)
  ///
  /// In en, this message translates to:
  /// **'No account? Your restaurant\'s admin adds staff from the VINII OS.'**
  String get authNoAccountNote;

  /// Heading of the forgot-password screen
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get authResetTitle;

  /// Forgot-password screen: line under the heading
  ///
  /// In en, this message translates to:
  /// **'Enter your work email. We will send a link to choose a new password.'**
  String get authResetIntro;

  /// Button on the forgot-password screen
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get authSendResetLink;

  /// Heading shown after the password reset email was requested
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get authResetSentTitle;

  /// Confirmation after requesting a password reset; never says whether the address has an account; {email} is what the person typed
  ///
  /// In en, this message translates to:
  /// **'If {email} has a VINII account, a link to set a new password is on its way. It can take a minute; check spam too.'**
  String authResetSentBody({required String email});

  /// Button on the password reset confirmation
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get authBackToSignIn;

  /// Title of the screen for a signed-in person who is not staff anywhere
  ///
  /// In en, this message translates to:
  /// **'No restaurant yet'**
  String get authNoAccessTitle;

  /// No-access screen when the signed-in email is not on any restaurant's staff; {email} is the login email
  ///
  /// In en, this message translates to:
  /// **'{email} is not on the staff of any restaurant. Ask your restaurant admin to add you from the VINII OS, then check again.'**
  String authNoAccessNotStaffEmail({required String email});

  /// No-access screen when the login email is not known
  ///
  /// In en, this message translates to:
  /// **'This account is not on the staff of any restaurant. Ask your restaurant admin to add you from the VINII OS, then check again.'**
  String get authNoAccessNotStaffAccount;

  /// No-access screen when the person's membership is suspended; {names} is a comma-separated list of organization names
  ///
  /// In en, this message translates to:
  /// **'Your access to {names} is paused. Ask the restaurant admin to turn it back on.'**
  String authNoAccessPaused({required String names});

  /// Button on the no-access screen that reloads the memberships
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get authCheckAgain;

  /// Splash screen: line under the VINII Partner name
  ///
  /// In en, this message translates to:
  /// **'Orders, POS and your storefront'**
  String get bootTagline;

  /// Splash screen problem title when the build has no database settings
  ///
  /// In en, this message translates to:
  /// **'This build is not connected'**
  String get bootNotConnectedTitle;

  /// Developer-facing splash message; {settings} are the missing setting names joined with 'and'
  ///
  /// In en, this message translates to:
  /// **'It is missing {settings}. Build it with ./tool/run_local.sh and a filled-in .env.local.'**
  String bootNotConnectedBody({required String settings});

  /// Splash screen problem title when starting failed because the phone is offline
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get bootNoConnection;

  /// Splash screen problem title when starting failed for another reason
  ///
  /// In en, this message translates to:
  /// **'Could not start'**
  String get bootCouldNotStart;

  /// Splash screen message when starting failed and no reason is known
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get bootSomethingWrong;

  /// Splash screen progress line, first step
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get bootStepStarting;

  /// Splash screen progress line while the app connects to the server
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get bootStepConnecting;

  /// Splash screen progress line while memberships are read
  ///
  /// In en, this message translates to:
  /// **'Finding your restaurants…'**
  String get bootStepFinding;

  /// Splash screen progress line while one organization is opened; {name} is the organization name
  ///
  /// In en, this message translates to:
  /// **'Opening {name}…'**
  String bootStepOpening({required String name});

  /// Title of the screen shown when this build is older than the organization requires
  ///
  /// In en, this message translates to:
  /// **'Update VINII Partner'**
  String get bootUpdateTitle;

  /// Update-required screen; {org} is the organization name, {needed} the minimum app version, {current} this build's version
  ///
  /// In en, this message translates to:
  /// **'{org} needs version {needed} or newer. This phone has {current}. Install the update from the store, then open the app again.'**
  String bootUpdateBodyOrg({
    required String org,
    required String needed,
    required String current,
  });

  /// Update-required screen when the organization name is not known
  ///
  /// In en, this message translates to:
  /// **'Your restaurant needs version {needed} or newer. This phone has {current}. Install the update from the store, then open the app again.'**
  String bootUpdateBodyDefault({
    required String needed,
    required String current,
  });

  /// Button on the update-required screen that re-reads the requirement
  ///
  /// In en, this message translates to:
  /// **'I have updated — check again'**
  String get bootUpdateCheckAgain;

  /// First intro page title
  ///
  /// In en, this message translates to:
  /// **'New orders ring here'**
  String get introOrdersTitle;

  /// First intro page text
  ///
  /// In en, this message translates to:
  /// **'Delivery orders from One Local ring on every signed-in phone. Accept with a prep time, or reject with a reason, within 60 seconds.'**
  String get introOrdersBody;

  /// Second intro page title
  ///
  /// In en, this message translates to:
  /// **'Take orders at the table'**
  String get introPosTitle;

  /// Second intro page text
  ///
  /// In en, this message translates to:
  /// **'Pick a table, add dishes and send the ticket straight to the kitchen. The POS sees the same order.'**
  String get introPosBody;

  /// Third intro page title
  ///
  /// In en, this message translates to:
  /// **'Your storefront, your way'**
  String get introStorefrontTitle;

  /// Third intro page text
  ///
  /// In en, this message translates to:
  /// **'Design the menu guests swipe through on their phones: your colours, your photos, budgets for groups, pre-orders. Preview it, then publish.'**
  String get introStorefrontBody;

  /// Button on the last intro page
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get introGetStarted;

  /// Organization picker greeting; {name} is the signed-in person's name
  ///
  /// In en, this message translates to:
  /// **'Hi {name}'**
  String orgGreeting({required String name});

  /// Heading of the organization picker
  ///
  /// In en, this message translates to:
  /// **'Choose a restaurant'**
  String get orgChooseTitle;

  /// Organization picker: line under the heading; 'More' is the name of the last bottom tab
  ///
  /// In en, this message translates to:
  /// **'You can switch any time from More.'**
  String get orgChooseHint;

  /// Chip on an organization whose access for this person is paused
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get orgPaused;

  /// Section label in More and row label in About
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get orgLabel;

  /// Button/row that goes back to the organization picker
  ///
  /// In en, this message translates to:
  /// **'Switch organization'**
  String get orgSwitch;

  /// Subtitle of the Switch organization row in More
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 restaurant on this login} other{{count} restaurants on this login}}'**
  String orgRestaurantsOnLogin({required int count});

  /// Bottom navigation tab: take orders at the counter or table
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get shellTabSell;

  /// Bottom navigation tab: the guest storefront designer
  ///
  /// In en, this message translates to:
  /// **'Storefront'**
  String get shellTabStorefront;

  /// More: section label above Bill & GST, Team and Table QR codes
  ///
  /// In en, this message translates to:
  /// **'Your restaurant'**
  String get settingsYourRestaurant;

  /// More: row title
  ///
  /// In en, this message translates to:
  /// **'Bill & GST'**
  String get settingsBillGst;

  /// More: subtitle of the Bill & GST row
  ///
  /// In en, this message translates to:
  /// **'GST, service charge and what is printed on bills'**
  String get settingsBillGstHint;

  /// More: row title
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get settingsTeam;

  /// More: subtitle of the Team row
  ///
  /// In en, this message translates to:
  /// **'Who works here and what each person can do'**
  String get settingsTeamHint;

  /// More: row title
  ///
  /// In en, this message translates to:
  /// **'Table QR codes'**
  String get settingsTableQr;

  /// More: subtitle of the Table QR codes row
  ///
  /// In en, this message translates to:
  /// **'One code per table for guests to scan'**
  String get settingsTableQrHint;

  /// More: section label above the Swiggy/Zomato switches
  ///
  /// In en, this message translates to:
  /// **'Sales channels'**
  String get settingsSalesChannels;

  /// More: section label above the ring settings
  ///
  /// In en, this message translates to:
  /// **'New-order alerts'**
  String get settingsAlertsLabel;

  /// More: switch title
  ///
  /// In en, this message translates to:
  /// **'Ring for new orders'**
  String get settingsRingTitle;

  /// More: subtitle of the ring switch
  ///
  /// In en, this message translates to:
  /// **'Vibration always stays on'**
  String get settingsRingSubtitle;

  /// More: row that plays the new-order sound for three seconds
  ///
  /// In en, this message translates to:
  /// **'Test the ring'**
  String get settingsRingTest;

  /// More: row title
  ///
  /// In en, this message translates to:
  /// **'Send a test order'**
  String get settingsTestOrder;

  /// More: subtitle of the Send a test order row
  ///
  /// In en, this message translates to:
  /// **'Creates a marked test order for this restaurant on One Local, to check the ring end to end'**
  String get settingsTestOrderHint;

  /// Snackbar after the test order was created
  ///
  /// In en, this message translates to:
  /// **'Test order sent. It will ring in a few seconds.'**
  String get settingsTestOrderSent;

  /// More: section label above the theme choice
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// Theme choice: follow the phone's light/dark setting
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get settingsThemeAuto;

  /// Theme choice: light
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// Theme choice: dark
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// More: row that opens the About screen
  ///
  /// In en, this message translates to:
  /// **'About this app'**
  String get settingsAbout;

  /// Title of the sign-out sheet
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get settingsSignOutTitle;

  /// Text of the sign-out sheet
  ///
  /// In en, this message translates to:
  /// **'This phone stops ringing for new orders until someone signs in again.'**
  String get settingsSignOutBody;

  /// Sign-out sheet button: this device only
  ///
  /// In en, this message translates to:
  /// **'Sign out of this phone'**
  String get settingsSignOutHere;

  /// Sign-out sheet button: every device the login is on
  ///
  /// In en, this message translates to:
  /// **'Sign out of every device'**
  String get settingsSignOutEverywhere;

  /// Title of the About screen
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// About screen: note above the list of build facts
  ///
  /// In en, this message translates to:
  /// **'Support may ask you to read these out. You do not need to change or do anything with them.'**
  String get aboutIntro;

  /// About screen: note under the list
  ///
  /// In en, this message translates to:
  /// **'VINII Partner shows only what is in your organization\'s database. It has no sample data.'**
  String get aboutFooter;

  /// About row label
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get aboutAppVersion;

  /// About row label (production, test, local)
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get aboutEnvironment;

  /// About row label
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get aboutDatabase;

  /// About row label
  ///
  /// In en, this message translates to:
  /// **'One Local server'**
  String get aboutOneLocalServer;

  /// About row value when the One Local server address is empty
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get aboutNotSet;

  /// About row label
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get aboutRole;

  /// About row label
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get aboutConfiguration;

  /// About row value: configuration version and where it came from ({source} is a technical word such as org_modules)
  ///
  /// In en, this message translates to:
  /// **'{version} · from {source}'**
  String aboutConfigValue({required String version, required String source});

  /// About row label
  ///
  /// In en, this message translates to:
  /// **'Minimum version'**
  String get aboutMinVersion;

  /// About row label: the bottom tabs this person sees
  ///
  /// In en, this message translates to:
  /// **'Tabs'**
  String get aboutTabs;

  /// Snackbar after a sales channel was switched on; {name} is the channel name
  ///
  /// In en, this message translates to:
  /// **'{name} is ON.'**
  String channelsOn({required String name});

  /// Snackbar after a sales channel was switched off; {name} is the channel name
  ///
  /// In en, this message translates to:
  /// **'{name} is OFF. You will not get {name} orders until you turn it on.'**
  String channelsOff({required String name});

  /// Snackbar action that switches the channel back on
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get channelsUndo;

  /// Button that reloads the sales channels after a failure
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get channelsRetry;

  /// Sales channels card when the restaurant has none
  ///
  /// In en, this message translates to:
  /// **'No sales channels are set up yet. Swiggy and Zomato show here once they are connected to this restaurant.'**
  String get channelsEmpty;

  /// Subtitle of a sales channel that is not connected
  ///
  /// In en, this message translates to:
  /// **'Not connected yet'**
  String get channelsNotConnected;

  /// Subtitle of a sales channel that is switched on
  ///
  /// In en, this message translates to:
  /// **'Taking orders'**
  String get channelsTaking;

  /// Subtitle of a sales channel that is switched off
  ///
  /// In en, this message translates to:
  /// **'Not taking orders'**
  String get channelsNotTaking;

  /// Failure: the channel_integrations table is missing
  ///
  /// In en, this message translates to:
  /// **'Sales channels are not set up in this database yet.'**
  String get channelsFailNotReady;

  /// Failure: the update of a sales channel changed no row
  ///
  /// In en, this message translates to:
  /// **'That channel could not be changed. You may not have permission.'**
  String get channelsFailNotChanged;

  /// Placeholder screen title for a feature that is not built yet
  ///
  /// In en, this message translates to:
  /// **'Being built'**
  String get uiBeingBuilt;

  /// Placeholder screen text
  ///
  /// In en, this message translates to:
  /// **'This screen is next.'**
  String get uiBeingBuiltHint;

  /// Label of the slide-to-confirm control while its action is running
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get uiSending;

  /// Second line of the Orders app bar, under the restaurant name
  ///
  /// In en, this message translates to:
  /// **'Delivery orders · One Local'**
  String get ordersSubtitle;

  /// Empty-state title on the Orders tab when this build has no One Local server
  ///
  /// In en, this message translates to:
  /// **'Delivery orders are not connected'**
  String get ordersNotConnected;

  /// Empty-state message on the Orders tab when no reason is available
  ///
  /// In en, this message translates to:
  /// **'This build cannot reach One Local right now.'**
  String get ordersNotConnectedFallback;

  /// Shown while an Orders tab loads
  ///
  /// In en, this message translates to:
  /// **'Loading orders…'**
  String get ordersLoading;

  /// Shown while one order's detail loads
  ///
  /// In en, this message translates to:
  /// **'Loading order…'**
  String get ordersLoadingOrder;

  /// Text button in the banner shown when the store status could not be loaded
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get ordersRetry;

  /// Banner on the Orders tab when the restaurant has no One Local channel yet
  ///
  /// In en, this message translates to:
  /// **'Not set up on One Local yet. Orders appear here once One Local adds this restaurant.'**
  String get ordersNotSetUp;

  /// Warning banner on the Orders tab: orders not answered in time, one after another
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 order missed in a row. After 3, One Local pauses the restaurant.} other{{count} orders missed in a row. After 3, One Local pauses the restaurant.}}'**
  String ordersMissedInARow({required int count});

  /// Banner above a list that failed to refresh; {message} is the reason the refresh failed
  ///
  /// In en, this message translates to:
  /// **'{message} Showing the last list this phone saw.'**
  String ordersShowingLastList({required String message});

  /// Empty New tab, title
  ///
  /// In en, this message translates to:
  /// **'No new orders'**
  String get ordersEmptyNewTitle;

  /// Empty New tab, message
  ///
  /// In en, this message translates to:
  /// **'When a customer orders, this phone rings.'**
  String get ordersEmptyNewMessage;

  /// Empty Preparing tab, title
  ///
  /// In en, this message translates to:
  /// **'Nothing cooking right now'**
  String get ordersEmptyPreparingTitle;

  /// Empty Preparing tab, message
  ///
  /// In en, this message translates to:
  /// **'Accepted orders stay here until they are ready.'**
  String get ordersEmptyPreparingMessage;

  /// Empty Ready tab, title
  ///
  /// In en, this message translates to:
  /// **'Nothing waiting for pickup'**
  String get ordersEmptyReadyTitle;

  /// Empty Ready tab, message
  ///
  /// In en, this message translates to:
  /// **'Ready and out-for-delivery orders show here.'**
  String get ordersEmptyReadyMessage;

  /// Empty Past tab, title
  ///
  /// In en, this message translates to:
  /// **'No past orders'**
  String get ordersEmptyPastTitle;

  /// Empty Past tab, message
  ///
  /// In en, this message translates to:
  /// **'Orders from the last 3 days show here.'**
  String get ordersEmptyPastMessage;

  /// Number of items in a delivery order (order card, detail section title)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String ordersItemCount({required int count});

  /// Order card on the Preparing tab: item count and the prep time the restaurant promised
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item · {minutes} min prep} other{{count} items · {minutes} min prep}}'**
  String ordersItemsPrep({required int count, required int minutes});

  /// Prep-time choice chip (10, 15, 20, 30, 45)
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String ordersMinutesShort({required int minutes});

  /// Label above the prep-time chips when accepting an order
  ///
  /// In en, this message translates to:
  /// **'Ready in'**
  String get ordersReadyIn;

  /// Main button on a new order: accept with the chosen prep time
  ///
  /// In en, this message translates to:
  /// **'Accept · {minutes} min'**
  String ordersAcceptWithPrep({required int minutes});

  /// Confirmation after accepting an order from the order detail
  ///
  /// In en, this message translates to:
  /// **'Accepted. Ready in {minutes} min.'**
  String ordersAcceptedDone({required int minutes});

  /// Button: reject a new order
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get ordersReject;

  /// Confirmation after rejecting an order from the order detail
  ///
  /// In en, this message translates to:
  /// **'Order rejected.'**
  String get ordersRejectedDone;

  /// Slide-to-confirm label: the order is ready for pickup
  ///
  /// In en, this message translates to:
  /// **'Mark ready'**
  String get ordersMarkReady;

  /// Confirmation after sliding Mark ready
  ///
  /// In en, this message translates to:
  /// **'Marked ready for pickup.'**
  String get ordersMarkedReadyDone;

  /// Slide-to-confirm label: the rider has taken the order
  ///
  /// In en, this message translates to:
  /// **'Out for delivery'**
  String get ordersSlideOut;

  /// Confirmation after sliding Out for delivery
  ///
  /// In en, this message translates to:
  /// **'On the way.'**
  String get ordersOnTheWayDone;

  /// Slide-to-confirm label: delivered and the cash was collected; {amount} is a rupee amount like ₹576
  ///
  /// In en, this message translates to:
  /// **'Delivered · cash {amount} collected'**
  String ordersSlideDelivered({required String amount});

  /// Confirmation after sliding Delivered; {amount} is a rupee amount
  ///
  /// In en, this message translates to:
  /// **'Delivered. {amount} cash recorded.'**
  String ordersDeliveredDone({required String amount});

  /// Shown at the bottom of an order when the signed-in role may not take the next step
  ///
  /// In en, this message translates to:
  /// **'Your role can view this order. A manager or biller moves it on.'**
  String get ordersViewOnlyRole;

  /// Banner on a cancelled order; {reason} is why it was cancelled
  ///
  /// In en, this message translates to:
  /// **'Cancelled: {reason}'**
  String ordersCancelledBanner({required String reason});

  /// Cancel reason written by the restaurant, e.g. Restaurant: Kitchen busy
  ///
  /// In en, this message translates to:
  /// **'Restaurant: {reason}'**
  String ordersCancelReasonByRestaurant({required String reason});

  /// Banner on an accepted order
  ///
  /// In en, this message translates to:
  /// **'Prep time: {minutes} min (the customer sees this).'**
  String ordersPrepTimeBanner({required int minutes});

  /// Section title for the note the customer wrote on the whole order
  ///
  /// In en, this message translates to:
  /// **'Customer note'**
  String get ordersCustomerNote;

  /// Bill line label (acronym stays Latin)
  ///
  /// In en, this message translates to:
  /// **'GST'**
  String get ordersGst;

  /// Bill line label
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get ordersDeliveryFee;

  /// How the customer pays: cash to the rider on delivery
  ///
  /// In en, this message translates to:
  /// **'Cash on delivery'**
  String get ordersPaymentCod;

  /// Section title of the order's step-by-step history
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get ordersTimeline;

  /// Order detail header: when it was placed, how long ago, and which marketplace sent it
  ///
  /// In en, this message translates to:
  /// **'Placed {time} · {ago} · {channel}'**
  String ordersPlacedLine({
    required String time,
    required String ago,
    required String channel,
  });

  /// Tooltip on the button that copies the customer's phone number
  ///
  /// In en, this message translates to:
  /// **'Copy number'**
  String get ordersCopyNumber;

  /// Confirmation after copying the customer's phone number
  ///
  /// In en, this message translates to:
  /// **'Phone number copied.'**
  String get ordersNumberCopied;

  /// Used inside a sentence when One Local did not send the other restaurant's name
  ///
  /// In en, this message translates to:
  /// **'another restaurant'**
  String get ordersAnotherRestaurant;

  /// Order timeline step 'placed'
  ///
  /// In en, this message translates to:
  /// **'Order placed'**
  String get ordersEventPlaced;

  /// Order timeline step 'accepted'
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get ordersEventAccepted;

  /// Order timeline step 'kot_fired'
  ///
  /// In en, this message translates to:
  /// **'Kitchen ticket sent'**
  String get ordersEventKotFired;

  /// Order timeline step 'kot_preparing'
  ///
  /// In en, this message translates to:
  /// **'Kitchen started'**
  String get ordersEventKotPreparing;

  /// Order timeline step 'kot_ready'
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ordersEventKotReady;

  /// Order timeline step 'out_for_delivery'
  ///
  /// In en, this message translates to:
  /// **'Out for delivery'**
  String get ordersEventOutForDelivery;

  /// Order timeline step 'delivered'
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get ordersEventDelivered;

  /// Order timeline step 'paid'
  ///
  /// In en, this message translates to:
  /// **'Cash collected'**
  String get ordersEventPaid;

  /// Order timeline step 'rejected'
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get ordersEventRejected;

  /// Order timeline step 'timed_out'
  ///
  /// In en, this message translates to:
  /// **'Not answered in time'**
  String get ordersEventTimedOut;

  /// Reject reason (the English text is what One Local receives)
  ///
  /// In en, this message translates to:
  /// **'Item out of stock'**
  String get ordersReasonOutOfStock;

  /// Reject reason (the English text is what One Local receives)
  ///
  /// In en, this message translates to:
  /// **'Kitchen busy'**
  String get ordersReasonKitchenBusy;

  /// Reject reason (the English text is what One Local receives)
  ///
  /// In en, this message translates to:
  /// **'Closing soon'**
  String get ordersReasonClosingSoon;

  /// Reject reason: the person types their own
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get ordersReasonOther;

  /// Title of the reject-reason sheet
  ///
  /// In en, this message translates to:
  /// **'Reject this order?'**
  String get ordersRejectTitle;

  /// Helper line in the reject-reason sheet
  ///
  /// In en, this message translates to:
  /// **'The customer sees the reason on One Local. Pick the closest one.'**
  String get ordersRejectIntro;

  /// Hint in the free-text reason field
  ///
  /// In en, this message translates to:
  /// **'e.g. Gas cylinder finished'**
  String get ordersRejectHint;

  /// Button in the reject-reason sheet that sends the rejection
  ///
  /// In en, this message translates to:
  /// **'Reject order'**
  String get ordersRejectConfirm;

  /// Button in the reject-reason sheet: do not reject
  ///
  /// In en, this message translates to:
  /// **'Keep the order'**
  String get ordersKeepOrder;

  /// Badge at the top of the full-screen new-order alert
  ///
  /// In en, this message translates to:
  /// **'NEW ORDER · One Local'**
  String get alertNewOrderBadge;

  /// Tooltip of the button that stops the ringing without answering
  ///
  /// In en, this message translates to:
  /// **'Silence'**
  String get alertSilence;

  /// Unit under the big countdown number in the new-order alert
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get alertSeconds;

  /// New-order alert: placed time and who ordered; {who} is the customer's first name and area
  ///
  /// In en, this message translates to:
  /// **'Placed {time} · {who}'**
  String alertPlacedLine({required String time, required String who});

  /// New-order alert: item count, label of the total amount next to it
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item · total} other{{count} items · total}}'**
  String alertItemsTotal({required int count});

  /// New-order alert for a role that may not accept
  ///
  /// In en, this message translates to:
  /// **'Only a manager or biller can accept orders. Ask them to answer this one.'**
  String get alertOnlyManager;

  /// Alert closing: title
  ///
  /// In en, this message translates to:
  /// **'Already answered'**
  String get alertAlreadyAnswered;

  /// Alert closing: message
  ///
  /// In en, this message translates to:
  /// **'This order is no longer waiting.'**
  String get alertNoLongerWaiting;

  /// Alert closing: title
  ///
  /// In en, this message translates to:
  /// **'Answered on another phone'**
  String get alertAnsweredElsewhere;

  /// Alert closing: message
  ///
  /// In en, this message translates to:
  /// **'Someone else in the restaurant took care of this order.'**
  String get alertAnsweredElsewhereMessage;

  /// Alert closing: the accept window ran out, title
  ///
  /// In en, this message translates to:
  /// **'Time\'s up'**
  String get alertTimeUp;

  /// Alert closing: message
  ///
  /// In en, this message translates to:
  /// **'The customer is told the restaurant didn\'t respond.'**
  String get alertTimeUpMessage;

  /// Alert shown for an instant while the order loads
  ///
  /// In en, this message translates to:
  /// **'One moment…'**
  String get alertOneMoment;

  /// Confirmation after accepting from the alert; {number} is the order number like OL-00031
  ///
  /// In en, this message translates to:
  /// **'Accepted {number}. Ready in {minutes} min.'**
  String alertAcceptedDone({required String number, required int minutes});

  /// Confirmation after rejecting from the alert; {number} is the order number
  ///
  /// In en, this message translates to:
  /// **'Rejected {number}. The customer has been told.'**
  String alertRejectedDone({required String number});

  /// Store status card title while the status loads
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get outletChecking;

  /// Store status card title when One Local could not be reached
  ///
  /// In en, this message translates to:
  /// **'Status unknown'**
  String get outletStatusUnknown;

  /// Store status card subtitle while the status loads
  ///
  /// In en, this message translates to:
  /// **'Asking One Local whether you are open'**
  String get outletAsking;

  /// Store status card subtitle when One Local could not be reached
  ///
  /// In en, this message translates to:
  /// **'Could not reach One Local'**
  String get outletCouldNotReach;

  /// Store status: open (state)
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get outletOpenTitle;

  /// Store status subtitle while open
  ///
  /// In en, this message translates to:
  /// **'Accepting orders. New ones ring on this phone.'**
  String get outletOpenSubtitle;

  /// Store status: paused (state)
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get outletPausedTitle;

  /// Store status subtitle while paused until a time; {when} is a time like 3:30 PM or tomorrow 9:00 AM
  ///
  /// In en, this message translates to:
  /// **'Back at {when}'**
  String outletPausedBackAt({required String when});

  /// Store status subtitle while paused with no end time
  ///
  /// In en, this message translates to:
  /// **'Until you turn it back on'**
  String get outletPausedUntilOn;

  /// Store status: closed for today (state)
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get outletClosedTitle;

  /// Store status subtitle while closed; {when} is a time
  ///
  /// In en, this message translates to:
  /// **'Closed for today. Opens {when}'**
  String outletClosedOpens({required String when});

  /// Store status subtitle while closed, no opening time
  ///
  /// In en, this message translates to:
  /// **'Closed for today'**
  String get outletClosedToday;

  /// Button: set the store to open
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get outletChoiceOpen;

  /// Button: pause new orders
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get outletChoicePause;

  /// Button: close the store for today
  ///
  /// In en, this message translates to:
  /// **'Close today'**
  String get outletChoiceClose;

  /// Shown with a lock to roles that may not change the store status
  ///
  /// In en, this message translates to:
  /// **'Only a manager can change this.'**
  String get outletOnlyManager;

  /// Screen-reader label of the store status card
  ///
  /// In en, this message translates to:
  /// **'Store status: {title}. {subtitle}'**
  String outletSemantics({required String title, required String subtitle});

  /// Confirmation after setting the store to open
  ///
  /// In en, this message translates to:
  /// **'Open. Accepting orders again.'**
  String get outletOpenDone;

  /// Confirmation after pausing with no end time
  ///
  /// In en, this message translates to:
  /// **'Paused until you turn it back on.'**
  String get outletPausedDoneIndefinite;

  /// Confirmation after pausing until a time
  ///
  /// In en, this message translates to:
  /// **'Paused. Back at {when}.'**
  String outletPausedDone({required String when});

  /// Confirmation after closing for today
  ///
  /// In en, this message translates to:
  /// **'Closed for today. Opens {when}.'**
  String outletClosedDone({required String when});

  /// A time that falls on the next day; {time} is like 9:00 AM
  ///
  /// In en, this message translates to:
  /// **'tomorrow {time}'**
  String outletWhenTomorrow({required String time});

  /// A time on a later day; {day} is like Sat, 16 Sep and {time} like 3:30 PM
  ///
  /// In en, this message translates to:
  /// **'{day}, {time}'**
  String outletWhenDay({required String day, required String time});

  /// Title of the sheet that asks how long to pause
  ///
  /// In en, this message translates to:
  /// **'Pause new orders'**
  String get outletPauseTitle;

  /// Helper text in the pause sheet
  ///
  /// In en, this message translates to:
  /// **'Customers will not be able to order from you on One Local. Orders you already accepted are not affected.'**
  String get outletPauseIntro;

  /// Pause length choice
  ///
  /// In en, this message translates to:
  /// **'30 minutes'**
  String get outletPause30;

  /// Pause length choice
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get outletPause1h;

  /// Pause length choice
  ///
  /// In en, this message translates to:
  /// **'2 hours'**
  String get outletPause2h;

  /// Pause length choice: no end time
  ///
  /// In en, this message translates to:
  /// **'Until I turn it back on'**
  String get outletPauseUntilOn;

  /// Button in the pause sheet: do not pause
  ///
  /// In en, this message translates to:
  /// **'Keep accepting'**
  String get outletKeepAccepting;

  /// Title of the close-for-today confirmation sheet
  ///
  /// In en, this message translates to:
  /// **'Close for today?'**
  String get outletCloseTitle;

  /// Helper text in the close sheet; {when} is when the store opens again
  ///
  /// In en, this message translates to:
  /// **'You stop getting delivery orders now and start again {when}. Orders you already accepted are not affected.'**
  String outletCloseIntro({required String when});

  /// Button in the close sheet that closes the store
  ///
  /// In en, this message translates to:
  /// **'Close for today'**
  String get outletCloseConfirm;

  /// Button in the close sheet: do not close
  ///
  /// In en, this message translates to:
  /// **'Keep open'**
  String get outletKeepOpen;

  /// Failure and empty-state message: no One Local server address in this build
  ///
  /// In en, this message translates to:
  /// **'Delivery orders come from One Local. This build does not have the One Local server address (PARTNER_API_BASE_URL), so it cannot show them.'**
  String get failOrdersUnavailable;

  /// Failure: One Local says the order is not found
  ///
  /// In en, this message translates to:
  /// **'That order no longer exists.'**
  String get failOrdersGone;

  /// Failure: another phone answered the order first
  ///
  /// In en, this message translates to:
  /// **'Someone else changed this order first.'**
  String get failOrdersChangedFirst;

  /// Failure: One Local refused the request
  ///
  /// In en, this message translates to:
  /// **'That request was not accepted.'**
  String get failOrdersRequestRefused;

  /// Failure: this app version is too old for One Local
  ///
  /// In en, this message translates to:
  /// **'Update the app to keep taking orders.'**
  String get failOrdersUpdateApp;

  /// Failure: One Local's own database is not connected
  ///
  /// In en, this message translates to:
  /// **'One Local is not connected to its database yet.'**
  String get failOrdersNotConnectedDb;

  /// Failure: One Local answered with an unexpected error; {status} is the error number
  ///
  /// In en, this message translates to:
  /// **'One Local could not do that (error {status}). Please try again.'**
  String failOrdersCouldNot({required String status});

  /// Failure: One Local did not answer in time
  ///
  /// In en, this message translates to:
  /// **'One Local is not answering. Check the connection and try again.'**
  String get failOrdersNotAnswering;

  /// Failure: One Local's reply could not be read
  ///
  /// In en, this message translates to:
  /// **'One Local sent an unexpected reply.'**
  String get failOrdersBadReply;

  /// Failure: the One Local login belongs to a different restaurant than the one chosen in this app
  ///
  /// In en, this message translates to:
  /// **'One Local links this login to {name}, not {org}. Delivery orders can be handled for one restaurant per login until One Local supports more.'**
  String failOrdersWrongOrg({required String name, required String org});

  /// Failure: a second tap while an order action is still being sent
  ///
  /// In en, this message translates to:
  /// **'Already sending…'**
  String get failOrdersAlreadySending;

  /// Title of the phone POS Sell screen (app bar)
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get sellTitle;

  /// Tooltip of the app bar button that hands the phone to the guest at a table
  ///
  /// In en, this message translates to:
  /// **'Hand to guest'**
  String get sellHandToGuest;

  /// Tooltip of the app bar button on Sell, and title of the sheet listing today's unpaid orders
  ///
  /// In en, this message translates to:
  /// **'Open orders'**
  String get posOpenOrders;

  /// Shown under the spinner while the Sell menu loads
  ///
  /// In en, this message translates to:
  /// **'Loading the menu…'**
  String get sellLoadingMenu;

  /// Empty state title on Sell when the restaurant has no menu items
  ///
  /// In en, this message translates to:
  /// **'No menu items yet'**
  String get sellNoMenuTitle;

  /// Empty state message on Sell when the restaurant has no menu items
  ///
  /// In en, this message translates to:
  /// **'No menu items yet. Add dishes in the Menu tab.'**
  String get sellNoMenuMessage;

  /// Button on the empty Sell screen that goes to the Menu tab
  ///
  /// In en, this message translates to:
  /// **'Open the Menu tab'**
  String get sellOpenMenuTab;

  /// Hint of the search box above the dishes on Sell
  ///
  /// In en, this message translates to:
  /// **'Search dishes'**
  String get sellSearchHint;

  /// Category chip for dishes that have no category
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get sellCategoryOther;

  /// Empty state title when the search or category shows no dishes
  ///
  /// In en, this message translates to:
  /// **'No dishes match'**
  String get sellNoMatchTitle;

  /// Empty state message when no dish matches; "All" is the first category chip
  ///
  /// In en, this message translates to:
  /// **'Try another name or pick \"All\".'**
  String get sellNoMatchMessage;

  /// Hint beside the Choose table chip on Sell while no table is picked
  ///
  /// In en, this message translates to:
  /// **'Dine-in orders need a table.'**
  String get sellDineInNeedsTable;

  /// Screen-reader label of a dish card that is not on the order; {name} is the dish, {price} the price
  ///
  /// In en, this message translates to:
  /// **'{name}, {price}'**
  String sellItemSemantics({required String name, required String price});

  /// Screen-reader label of a dish card that is already on the order; {qty} is how many
  ///
  /// In en, this message translates to:
  /// **'{name}, {price}, {qty} in order'**
  String sellItemInOrderSemantics({
    required String name,
    required String price,
    required int qty,
  });

  /// Screen-reader label of a dish card that is sold out
  ///
  /// In en, this message translates to:
  /// **'{name}, sold out'**
  String sellItemSoldOutSemantics({required String name});

  /// Snackbar after tapping a sold-out dish
  ///
  /// In en, this message translates to:
  /// **'{name} is sold out.'**
  String sellItemSoldOutNotice({required String name});

  /// Badge on the picture of a sold-out dish
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get sellSoldOut;

  /// Screen-reader label of the + button on a dish card
  ///
  /// In en, this message translates to:
  /// **'Add {name}'**
  String sellAddItem({required String name});

  /// Screen-reader label of the minus button of a quantity stepper (also the bin when it removes the last one)
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get sellLess;

  /// Screen-reader label of the plus button of a quantity stepper
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get sellMore;

  /// Bottom bar on Sell: how many items are on the order and the estimated total; {total} is a formatted rupee amount
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item · {total}} other{{count} items · {total}}}'**
  String sellCartSummary({required int count, required String total});

  /// Small note under the running total on the Sell bottom bar
  ///
  /// In en, this message translates to:
  /// **'(estimated)'**
  String get sellEstimatedNote;

  /// Button on the Sell bottom bar that opens the Review order screen
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get sellReview;

  /// Why the order cannot be sent: nothing on it
  ///
  /// In en, this message translates to:
  /// **'Add at least one item.'**
  String get sellBlockerEmpty;

  /// Why the order cannot be sent: dine-in without a table
  ///
  /// In en, this message translates to:
  /// **'Choose a table for this dine-in order.'**
  String get sellBlockerNoTable;

  /// Why the order cannot be sent: delivery without a phone number
  ///
  /// In en, this message translates to:
  /// **'Add the customer\'s phone number for delivery.'**
  String get sellBlockerNoPhone;

  /// Failure shown if the send button is pressed while the order is already being sent
  ///
  /// In en, this message translates to:
  /// **'Already sending…'**
  String get sellAlreadySending;

  /// Label of the chip that opens the table picker while no table is chosen
  ///
  /// In en, this message translates to:
  /// **'Choose table'**
  String get posChooseTable;

  /// Name of a table whose label is only a number, e.g. Table 12
  ///
  /// In en, this message translates to:
  /// **'Table {number}'**
  String posTableNumber({required String number});

  /// Number of seats on a table tile in the table picker
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 seat} other{{count} seats}}'**
  String posSeats({required int count});

  /// Marks a table tile that has an unpaid order
  ///
  /// In en, this message translates to:
  /// **'Occupied'**
  String get posTableOccupied;

  /// Section heading in the table picker for tables that belong to no floor area
  ///
  /// In en, this message translates to:
  /// **'Other tables'**
  String get posOtherTables;

  /// Empty state title of the table picker
  ///
  /// In en, this message translates to:
  /// **'No tables set up'**
  String get posNoTablesTitle;

  /// Empty state message of the table picker; VINII OS is the product name
  ///
  /// In en, this message translates to:
  /// **'No tables set up. Add them in the VINII OS.'**
  String get posNoTablesMessage;

  /// Title of the table picker sheet
  ///
  /// In en, this message translates to:
  /// **'Choose a table'**
  String get posChooseTableTitle;

  /// Helper line under the table picker title
  ///
  /// In en, this message translates to:
  /// **'Tables with an unpaid order are marked occupied.'**
  String get posTablesHelp;

  /// Total line of the estimated bill on the review screen
  ///
  /// In en, this message translates to:
  /// **'Estimated total'**
  String get posBillEstimatedTotal;

  /// Note under the estimated bill
  ///
  /// In en, this message translates to:
  /// **'Estimated. The POS confirms the final bill.'**
  String get posEstimatedNote;

  /// Bill line: the total of the items before charges and tax
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get posBillItems;

  /// Bill line: state GST; {percent} is the rate such as 2.5%
  ///
  /// In en, this message translates to:
  /// **'SGST ({percent})'**
  String posBillSgst({required String percent});

  /// Bill line: central GST; {percent} is the rate such as 2.5%
  ///
  /// In en, this message translates to:
  /// **'CGST ({percent})'**
  String posBillCgst({required String percent});

  /// Bill line: rounding to the nearest rupee
  ///
  /// In en, this message translates to:
  /// **'Round off'**
  String get posBillRoundOff;

  /// Bill line on a saved order: how much has been paid so far
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get posBillPaid;

  /// Bill line on a saved order: how much is still to pay
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get posBillDue;

  /// Under the dish name in the quantity sheet; {price} is the unit price
  ///
  /// In en, this message translates to:
  /// **'{price} each'**
  String sellPriceEach({required String price});

  /// Label of the kitchen note field in the dish quantity sheet
  ///
  /// In en, this message translates to:
  /// **'Note for the kitchen'**
  String get sellKitchenNoteLabel;

  /// Hint of a note for the kitchen on one dish
  ///
  /// In en, this message translates to:
  /// **'e.g. Less spicy, no onion'**
  String get sellNoteHint;

  /// Button of the dish quantity sheet when the dish is already on the order; {total} is the line total
  ///
  /// In en, this message translates to:
  /// **'Update · {total}'**
  String sellLineUpdate({required String total});

  /// Button of the dish quantity sheet when the dish is not on the order yet; {total} is the line total
  ///
  /// In en, this message translates to:
  /// **'Add · {total}'**
  String sellLineAdd({required String total});

  /// Button of the dish quantity sheet that takes the dish off the order
  ///
  /// In en, this message translates to:
  /// **'Remove from order'**
  String get sellRemoveFromOrder;

  /// Snackbar after the order was sent with a kitchen ticket; {orderNo} is the order number such as ORD-65005553
  ///
  /// In en, this message translates to:
  /// **'{orderNo} sent to the kitchen.'**
  String ticketSentToKitchen({required String orderNo});

  /// Snackbar after the order was saved without a kitchen ticket
  ///
  /// In en, this message translates to:
  /// **'{orderNo} saved and held.'**
  String ticketSavedHeld({required String orderNo});

  /// Dialog title: the server already had an order from an unanswered earlier send
  ///
  /// In en, this message translates to:
  /// **'An earlier order went through'**
  String get ticketEarlierTitle;

  /// Dialog body of the earlier-order notice
  ///
  /// In en, this message translates to:
  /// **'This phone\'s earlier order was saved as {orderNo}. Your cart is still here. Send it again to make a new order.'**
  String ticketEarlierBody({required String orderNo});

  /// Dialog button that opens the earlier order
  ///
  /// In en, this message translates to:
  /// **'Open {orderNo}'**
  String ticketOpenOrder({required String orderNo});

  /// Dialog button that keeps the current cart
  ///
  /// In en, this message translates to:
  /// **'Keep this cart'**
  String get ticketKeepCart;

  /// Dialog title when clearing the order being built
  ///
  /// In en, this message translates to:
  /// **'Clear this order?'**
  String get ticketClearTitle;

  /// Dialog body when clearing the order being built
  ///
  /// In en, this message translates to:
  /// **'Everything on it is removed. It has not been sent.'**
  String get ticketClearBody;

  /// Dialog button: do not clear the order
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get ticketKeepIt;

  /// Dialog button: clear the order
  ///
  /// In en, this message translates to:
  /// **'Clear order'**
  String get ticketClearConfirm;

  /// Title of the dialog that edits the kitchen note of one line; {name} is the dish
  ///
  /// In en, this message translates to:
  /// **'Note for {name}'**
  String ticketNoteFor({required String name});

  /// Empty state title of the order being built
  ///
  /// In en, this message translates to:
  /// **'The order is empty'**
  String get ticketEmptyTitle;

  /// Empty state message of the order pane beside the menu
  ///
  /// In en, this message translates to:
  /// **'Tap a dish to add it.'**
  String get ticketEmptyEmbedded;

  /// Empty state message of the Review order screen
  ///
  /// In en, this message translates to:
  /// **'Add dishes on the Sell screen.'**
  String get ticketEmptyMessage;

  /// Button on the empty Review order screen
  ///
  /// In en, this message translates to:
  /// **'Back to the menu'**
  String get ticketBackToMenu;

  /// Heading of the order pane beside the menu
  ///
  /// In en, this message translates to:
  /// **'Current order'**
  String get ticketCurrentOrder;

  /// Banner on the order when an earlier send is unanswered
  ///
  /// In en, this message translates to:
  /// **'An earlier send from this phone did not get an answer. Sending again checks for it first, so nothing is made twice.'**
  String get ticketPendingSendNotice;

  /// Card heading above Dine-in / Takeaway / Delivery
  ///
  /// In en, this message translates to:
  /// **'Order type'**
  String get ticketOrderType;

  /// Label of the guest count stepper on a dine-in order
  ///
  /// In en, this message translates to:
  /// **'Guests'**
  String get ticketGuests;

  /// Field label on takeaway and delivery orders
  ///
  /// In en, this message translates to:
  /// **'Customer name (optional)'**
  String get ticketCustomerNameOptional;

  /// Field label on a delivery order, where the phone is required
  ///
  /// In en, this message translates to:
  /// **'Customer phone'**
  String get ticketCustomerPhone;

  /// Field label on a takeaway order
  ///
  /// In en, this message translates to:
  /// **'Customer phone (optional)'**
  String get ticketCustomerPhoneOptional;

  /// Helper text under the phone field on a delivery order
  ///
  /// In en, this message translates to:
  /// **'Needed so the rider can reach the customer.'**
  String get ticketPhoneHelper;

  /// Heading of the list of lines on an order
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String posItemCount({required int count});

  /// Card heading above the note for the whole order
  ///
  /// In en, this message translates to:
  /// **'Order note'**
  String get ticketOrderNote;

  /// Hint of the note for the whole order
  ///
  /// In en, this message translates to:
  /// **'For the whole order, e.g. Serve starters first'**
  String get ticketOrderNoteHint;

  /// Button: save the order without sending a kitchen ticket
  ///
  /// In en, this message translates to:
  /// **'Save & hold'**
  String get ticketSaveHold;

  /// Button: save the order and send the kitchen ticket; {total} is the estimated total
  ///
  /// In en, this message translates to:
  /// **'Send to kitchen · {total}'**
  String ticketSendToKitchen({required String total});

  /// Link under a line of the order that has no kitchen note yet
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get ticketAddNote;

  /// App bar button on a saved order that starts a new one
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get posNewOrder;

  /// Shown while a saved order loads
  ///
  /// In en, this message translates to:
  /// **'Loading order…'**
  String get posLoadingOrder;

  /// Snackbar after a manager removed the service charge from a saved order
  ///
  /// In en, this message translates to:
  /// **'Service charge removed.'**
  String get posServiceChargeRemoved;

  /// Snackbar after a manager put the service charge back on a saved order
  ///
  /// In en, this message translates to:
  /// **'Service charge added back.'**
  String get posServiceChargeAdded;

  /// Banner on a cancelled saved order
  ///
  /// In en, this message translates to:
  /// **'This order was cancelled. Nothing is due.'**
  String get posCancelledNotice;

  /// Headline of the confirmation of an order that was already paid; {total} is the bill total
  ///
  /// In en, this message translates to:
  /// **'Paid · {total}'**
  String posPaidHeadline({required String total});

  /// Headline of the confirmation after paying here; {methods} is e.g. Cash or Cash + UPI
  ///
  /// In en, this message translates to:
  /// **'Paid · {total} by {methods}'**
  String posPaidByHeadline({required String total, required String methods});

  /// Note shown instead of the payment form to a role that may not take payment
  ///
  /// In en, this message translates to:
  /// **'A biller or manager takes the payment for this order.'**
  String get posPaymentByBiller;

  /// Empty state title of the open orders sheet
  ///
  /// In en, this message translates to:
  /// **'No open orders'**
  String get posOpenOrdersEmptyTitle;

  /// Empty state message of the open orders sheet
  ///
  /// In en, this message translates to:
  /// **'Today\'s unpaid orders show here, from this phone and the POS.'**
  String get posOpenOrdersEmptyMessage;

  /// Amount still to pay, on a part-paid order in the open orders sheet; {amount} is a rupee amount
  ///
  /// In en, this message translates to:
  /// **'Due {amount}'**
  String posOpenDue({required String amount});

  /// App bar title of the review screen before an order is saved
  ///
  /// In en, this message translates to:
  /// **'Review order'**
  String get payReviewOrder;

  /// Title of the payment card on an order
  ///
  /// In en, this message translates to:
  /// **'Take payment'**
  String get payTakePayment;

  /// Main button of the payment card while no amount is known yet
  ///
  /// In en, this message translates to:
  /// **'Charge'**
  String get payCharge;

  /// Main button of the payment card; {amount} is the rupees it will take
  ///
  /// In en, this message translates to:
  /// **'Charge {amount}'**
  String payChargeAmount({required String amount});

  /// Fourth tile next to Cash, UPI and Card: pay one bill with two methods
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get paySplit;

  /// Field label: the cash the guest handed over
  ///
  /// In en, this message translates to:
  /// **'Cash received (optional)'**
  String get payCashReceivedOptional;

  /// Helper text under the cash received field
  ///
  /// In en, this message translates to:
  /// **'Type what the guest handed over to see the change.'**
  String get payCashReceivedHelper;

  /// Shortcut button: the guest gave exactly the amount due
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get payExact;

  /// Field label: transaction reference of a UPI payment
  ///
  /// In en, this message translates to:
  /// **'UPI reference (optional)'**
  String get payUpiReferenceOptional;

  /// Field label: number printed on the card machine slip
  ///
  /// In en, this message translates to:
  /// **'Card slip number (optional)'**
  String get payCardSlipOptional;

  /// Label next to the change the cashier must hand back, while taking cash
  ///
  /// In en, this message translates to:
  /// **'Change to return'**
  String get payChangeToReturn;

  /// Split payment: the two parts add up to what is due
  ///
  /// In en, this message translates to:
  /// **'Covered'**
  String get payCovered;

  /// Split payment status label; the amount is shown to its right
  ///
  /// In en, this message translates to:
  /// **'Short by'**
  String get payShortByLabel;

  /// Split payment status label; the amount is shown to its right
  ///
  /// In en, this message translates to:
  /// **'Over by'**
  String get payOverByLabel;

  /// Heading of one of the two parts of a split payment
  ///
  /// In en, this message translates to:
  /// **'Part {index}'**
  String payPart({required int index});

  /// Field label for the rupees of one part of a split payment
  ///
  /// In en, this message translates to:
  /// **'Part {index} amount'**
  String payPartAmount({required int index});

  /// Button: fill this part with what the other part leaves of the bill
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get payRest;

  /// Problem line under the amount field when it is empty or zero
  ///
  /// In en, this message translates to:
  /// **'Enter the amount.'**
  String get payEnterAmount;

  /// Problem line: the amount typed is above what is due; {due} is rupees
  ///
  /// In en, this message translates to:
  /// **'That is more than the {due} due.'**
  String payMoreThanDue({required String due});

  /// Problem line: cash handed over is below the amount being charged; {amount} is rupees
  ///
  /// In en, this message translates to:
  /// **'Cash received is less than {amount}.'**
  String payCashLess({required String amount});

  /// Problem line on a split payment when a part is empty
  ///
  /// In en, this message translates to:
  /// **'Enter an amount for both parts.'**
  String get payEnterBothParts;

  /// Problem line on a split payment: the parts add up to less than the bill; {amount} is rupees
  ///
  /// In en, this message translates to:
  /// **'Short by {amount}.'**
  String payShortBy({required String amount});

  /// Problem line on a split payment: the parts add up to more than the bill; {amount} is rupees
  ///
  /// In en, this message translates to:
  /// **'Over by {amount}.'**
  String payOverBy({required String amount});

  /// Confirmation after the last rupee of a bill is taken
  ///
  /// In en, this message translates to:
  /// **'Paid in full.'**
  String get payPaidInFull;

  /// Confirmation after a part payment; {method} is Cash, UPI or Card; {amount} and {due} are rupees
  ///
  /// In en, this message translates to:
  /// **'{amount} received by {method}. {due} still due.'**
  String payReceivedBy({
    required String amount,
    required String method,
    required String due,
  });

  /// Warning on the payment card after the second part of a split failed; {method} is Cash, UPI or Card
  ///
  /// In en, this message translates to:
  /// **'The first part is recorded. The second part ({method} {amount}) was not confirmed.'**
  String payRetryBanner({required String method, required String amount});

  /// Button: give up the failed second part and take the rest of the bill a different way
  ///
  /// In en, this message translates to:
  /// **'Take it another way'**
  String get payTakeAnotherWay;

  /// Payment success card: cash to hand back to the guest
  ///
  /// In en, this message translates to:
  /// **'Give back change'**
  String get paySuccessGiveBackChange;

  /// Payment success card: button to start the next order
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get paySuccessNewOrder;

  /// Row of a bill
  ///
  /// In en, this message translates to:
  /// **'Service charge'**
  String get serviceChargeLabel;

  /// Row of a bill; {percent} is the rate without trailing zeros, e.g. 10 or 7.5
  ///
  /// In en, this message translates to:
  /// **'Service charge ({percent}%)'**
  String serviceChargeLabelPercent({required String percent});

  /// Button on the service charge row after it was removed: put it back on the bill
  ///
  /// In en, this message translates to:
  /// **'Add back'**
  String get serviceChargeAddBack;

  /// Small tag on the service charge row after a manager removed it
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get serviceChargeRemoved;

  /// Title of the bottom sheet that asks before the service charge comes off
  ///
  /// In en, this message translates to:
  /// **'Remove the service charge from this bill?'**
  String get serviceChargeRemoveTitle;

  /// Body of the remove service charge sheet; {amount} is rupees (the charge and the GST on it)
  ///
  /// In en, this message translates to:
  /// **'The guest will pay {amount} less. This is recorded with your name.'**
  String serviceChargeRemoveBody({required String amount});

  /// Field label for why the service charge is removed
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get serviceChargeReasonLabel;

  /// Hint inside the reason field of the remove service charge sheet
  ///
  /// In en, this message translates to:
  /// **'e.g. Regular guest, complaint about service'**
  String get serviceChargeReasonHint;

  /// Main button of the remove service charge sheet
  ///
  /// In en, this message translates to:
  /// **'Remove service charge'**
  String get serviceChargeRemoveConfirm;

  /// Button of the remove service charge sheet: leave the charge on the bill
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get serviceChargeKeepIt;

  /// Question card above the payment form; {amount} is rupees
  ///
  /// In en, this message translates to:
  /// **'Service charge {amount} is on this bill. Remove it?'**
  String serviceChargePrompt({required String amount});

  /// Answer on the service charge question card: leave it on the bill
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get serviceChargeKeep;

  /// Failure code pay_second_part_failed; {reason} is the sentence for what went wrong
  ///
  /// In en, this message translates to:
  /// **'The first part was received, but the second was not confirmed. {reason}'**
  String failPaySecondPartFailed({required String reason});

  /// Failure code pay_add_item: placing an order with no lines
  ///
  /// In en, this message translates to:
  /// **'Add at least one item.'**
  String get failPayAddItem;

  /// Failure code pay_bad_order_shape
  ///
  /// In en, this message translates to:
  /// **'The server sent an order in a shape this app does not understand.'**
  String get failPayBadOrderShape;

  /// Failure code pay_tables_not_ready
  ///
  /// In en, this message translates to:
  /// **'Tables are not set up in this database yet.'**
  String get failPayTablesNotReady;

  /// Failure code pay_place_not_ready
  ///
  /// In en, this message translates to:
  /// **'Taking orders from the phone needs the POS order functions, a database update waiting for approval. Until then, take this order at the POS counter.'**
  String get failPayPlaceNotReady;

  /// Failure code pay_record_not_ready
  ///
  /// In en, this message translates to:
  /// **'Recording payments from the phone needs the POS payment function, a database update waiting for approval. Settle this bill at the POS counter.'**
  String get failPayRecordNotReady;

  /// Failure code pay_status_not_ready
  ///
  /// In en, this message translates to:
  /// **'Changing order status from the phone needs the POS status function, a database update waiting for approval.'**
  String get failPayStatusNotReady;

  /// Failure code charge_adjust_not_ready
  ///
  /// In en, this message translates to:
  /// **'Changing the service charge on a saved order needs a database update that is waiting for approval. Until then, remove it before the order is sent, or change the bill at the POS counter.'**
  String get failChargeAdjustNotReady;

  /// Menu tab: app-bar button that opens the categories screen, title of that screen, and the Categories count label on the menu list
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get menuCategories;

  /// Menu tab: floating button that starts a new dish
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get menuAddItem;

  /// Menu tab: shown under the spinner while the menu loads
  ///
  /// In en, this message translates to:
  /// **'Loading your menu…'**
  String get menuLoading;

  /// Menu tab: placeholder of the search field
  ///
  /// In en, this message translates to:
  /// **'Search dishes'**
  String get menuSearchHint;

  /// Menu tab: tooltip of the X button in the search field
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get menuSearchClear;

  /// Menu tab: label under the number of dishes at the top of the list
  ///
  /// In en, this message translates to:
  /// **'Dishes'**
  String get menuStatDishes;

  /// Menu tab: label under the number of sold-out dishes at the top, and the red mark on a dish whose availability switch is off
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get menuSoldOut;

  /// Menu and Categories screens: banner above the list when a reload failed; {reason} is the failure sentence
  ///
  /// In en, this message translates to:
  /// **'Could not refresh. {reason}'**
  String menuRefreshFailed({required String reason});

  /// Menu tab: heading of one category group; {name} is the category's own name (or Uncategorised), {count} the number of dishes in it
  ///
  /// In en, this message translates to:
  /// **'{name} · {count}'**
  String menuCategoryHeading({required String name, required int count});

  /// Name the app gives to dishes that have no category (menu list group, category picker choice)
  ///
  /// In en, this message translates to:
  /// **'Uncategorised'**
  String get menuUncategorised;

  /// Menu tab: title of the empty result when the search finds nothing; {query} is what the person typed
  ///
  /// In en, this message translates to:
  /// **'No dishes match \"{query}\"'**
  String menuNoMatchTitle({required String query});

  /// Menu tab: hint under the no-match title
  ///
  /// In en, this message translates to:
  /// **'Try another word, or clear the search.'**
  String get menuNoMatchMessage;

  /// Screen-reader label of the availability switch on a dish row
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get menuAvailable;

  /// Mark on a dish flagged as recommended; also the title of the Bestseller switch in the item editor and the Bestseller storefront tag
  ///
  /// In en, this message translates to:
  /// **'Bestseller'**
  String get menuBestseller;

  /// Menu tab: row shown inside a category with no dishes
  ///
  /// In en, this message translates to:
  /// **'No dishes in this category yet'**
  String get menuCategoryEmpty;

  /// Button that starts a new dish (empty category row and empty menu)
  ///
  /// In en, this message translates to:
  /// **'Add a dish'**
  String get menuAddDish;

  /// Menu tab: title when there are no categories and no dishes
  ///
  /// In en, this message translates to:
  /// **'Your menu is empty'**
  String get menuEmptyTitle;

  /// Menu tab: empty-menu explanation for someone who may edit the menu
  ///
  /// In en, this message translates to:
  /// **'Add a category first, then your dishes. The POS, One Local and your storefront all sell from this one menu.'**
  String get menuEmptyBodyEditor;

  /// Menu tab: empty-menu explanation for someone who may only view the menu
  ///
  /// In en, this message translates to:
  /// **'Nothing on the menu yet. An owner or manager can add dishes.'**
  String get menuEmptyBodyViewer;

  /// Button that opens the new-category dialog (empty menu, empty categories screen)
  ///
  /// In en, this message translates to:
  /// **'Add a category'**
  String get menuAddACategory;

  /// Item editor: app-bar title when creating a dish
  ///
  /// In en, this message translates to:
  /// **'New item'**
  String get menuItemNewTitle;

  /// Item editor: app-bar title when changing a dish
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get menuItemEditTitle;

  /// Item editor: bottom button that saves a brand-new dish
  ///
  /// In en, this message translates to:
  /// **'Add to menu'**
  String get menuItemAddToMenu;

  /// Item editor: bottom button that saves an existing dish
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get menuItemSaveChanges;

  /// Item editor: confirmation after a new dish is saved; {name} is the dish name
  ///
  /// In en, this message translates to:
  /// **'{name} is on the menu'**
  String menuItemAdded({required String name});

  /// Item editor: confirmation after changes to a dish are saved
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get menuSaved;

  /// Item editor: title when the dish being opened was deleted
  ///
  /// In en, this message translates to:
  /// **'This dish is no longer on the menu'**
  String get menuItemGoneTitle;

  /// Item editor: explanation under the dish-gone title
  ///
  /// In en, this message translates to:
  /// **'Someone may have removed it on another device.'**
  String get menuItemGoneMessage;

  /// Item editor: button on the dish-gone screen
  ///
  /// In en, this message translates to:
  /// **'Back to menu'**
  String get menuItemBackToMenu;

  /// Item editor: banner shown to staff who may look but not edit
  ///
  /// In en, this message translates to:
  /// **'Only owners, admins and managers can change dishes.'**
  String get menuItemReadOnlyNotice;

  /// Item editor: heading of the card with name, description, price
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get menuSectionDetails;

  /// Item editor: heading of the card with category, food type and course
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get menuSectionKind;

  /// Item editor: heading of the card with the Bestseller and Available switches
  ///
  /// In en, this message translates to:
  /// **'Selling'**
  String get menuSectionSelling;

  /// Item editor: heading of the card with the guest-only details
  ///
  /// In en, this message translates to:
  /// **'On your storefront'**
  String get menuSectionStorefront;

  /// Item editor: error under the name field when it is empty
  ///
  /// In en, this message translates to:
  /// **'Give the dish a name'**
  String get menuItemNameRequired;

  /// Item editor: label of the description field
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get menuItemDescription;

  /// Item editor: placeholder of the description field
  ///
  /// In en, this message translates to:
  /// **'What makes it good, in a line or two'**
  String get menuItemDescriptionHint;

  /// Item editor: helper text under the price field (the price excludes GST)
  ///
  /// In en, this message translates to:
  /// **'Before GST'**
  String get menuItemBeforeGst;

  /// Item editor: error under the price field when it is empty or not a number
  ///
  /// In en, this message translates to:
  /// **'Enter a price'**
  String get menuItemPriceRequired;

  /// Item editor: error under the price field when it is below zero
  ///
  /// In en, this message translates to:
  /// **'Price cannot be negative'**
  String get menuItemPriceNegative;

  /// Item editor: label of the preparation-time field
  ///
  /// In en, this message translates to:
  /// **'Prep time'**
  String get menuItemPrepTime;

  /// Item editor: unit shown after the preparation-time number
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get menuMinutesShort;

  /// Item editor, read-only view: line showing the dish price; {price} is already formatted as rupees
  ///
  /// In en, this message translates to:
  /// **'Sells at {price} before GST'**
  String menuItemSellsAt({required String price});

  /// Item editor: label above the Veg / Non-veg / Egg chips
  ///
  /// In en, this message translates to:
  /// **'Food type'**
  String get menuFoodType;

  /// Diet marker: vegetarian dish (food_type veg); also the screen-reader label of the veg mark
  ///
  /// In en, this message translates to:
  /// **'Veg'**
  String get menuFoodTypeVeg;

  /// Diet marker: non-vegetarian dish (food_type non_veg); also the screen-reader label of the non-veg mark
  ///
  /// In en, this message translates to:
  /// **'Non-veg'**
  String get menuFoodTypeNonVeg;

  /// Diet marker: dish containing egg (food_type egg); also the screen-reader label of the egg mark
  ///
  /// In en, this message translates to:
  /// **'Egg'**
  String get menuFoodTypeEgg;

  /// Item editor: chip meaning the dish has no diet marker
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get menuFoodTypeNotSet;

  /// Item editor: label above the Food / Drink choice
  ///
  /// In en, this message translates to:
  /// **'Course'**
  String get menuCourse;

  /// Item editor: segment for a dish that is eaten (course eat)
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get menuCourseFood;

  /// Item editor: segment for a dish that is drunk (course drink)
  ///
  /// In en, this message translates to:
  /// **'Drink'**
  String get menuCourseDrink;

  /// Item editor: subtitle of the Bestseller switch
  ///
  /// In en, this message translates to:
  /// **'Marked for guests and on the POS'**
  String get menuBestsellerHint;

  /// Item editor: title of the availability switch
  ///
  /// In en, this message translates to:
  /// **'Available in the POS'**
  String get menuAvailablePos;

  /// Item editor: subtitle of the availability switch
  ///
  /// In en, this message translates to:
  /// **'Off = sold out everywhere you sell'**
  String get menuAvailablePosHint;

  /// Item editor: photo sheet option that opens the camera
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get menuPhotoTake;

  /// Item editor: photo sheet option that opens the photo library
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get menuPhotoGallery;

  /// Item editor: photo sheet option that clears the dish photo
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get menuPhotoRemove;

  /// Item editor: button on the dish picture when it already has a photo
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get menuPhotoChange;

  /// Item editor: button on the dish picture when it has no photo
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get menuPhotoAdd;

  /// Item editor, read-only view: caption on the dish picture when it has no photo
  ///
  /// In en, this message translates to:
  /// **'No photo yet'**
  String get menuPhotoNone;

  /// Item editor: confirmation after a photo was uploaded
  ///
  /// In en, this message translates to:
  /// **'Photo uploaded. Save to keep it on the dish.'**
  String get menuPhotoUploaded;

  /// Dialog title when leaving a screen with unsaved changes
  ///
  /// In en, this message translates to:
  /// **'Discard your changes?'**
  String get menuDiscardTitle;

  /// Dialog text when leaving a screen with unsaved changes
  ///
  /// In en, this message translates to:
  /// **'What you changed on this screen has not been saved.'**
  String get menuDiscardMessage;

  /// Dialog button: stay on the screen and keep the changes
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get menuKeepEditing;

  /// Dialog button: leave the screen and throw the changes away
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get menuDiscard;

  /// Categories screen: title of the dialog that asks for a new category name
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get menuCategoryNewTitle;

  /// Categories screen: confirmation after adding a category; {name} is the category name
  ///
  /// In en, this message translates to:
  /// **'Added {name}'**
  String menuCategoryAdded({required String name});

  /// Categories screen: title of the rename dialog
  ///
  /// In en, this message translates to:
  /// **'Rename category'**
  String get menuCategoryRenameTitle;

  /// Categories screen: delete confirmation title; {name} is the category name
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String menuCategoryDeleteTitle({required String name});

  /// Categories screen: delete confirmation text for an empty category
  ///
  /// In en, this message translates to:
  /// **'There are no dishes in it.'**
  String get menuCategoryDeleteEmpty;

  /// Categories screen: delete confirmation text for a category that has dishes; the dishes are kept
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Items in it stay on your menu as Uncategorised (1 dish).} other{Items in it stay on your menu as Uncategorised ({count} dishes).}}'**
  String menuCategoryDeleteKeeps({required int count});

  /// Categories screen: confirmation after deleting a category; {name} is the category name
  ///
  /// In en, this message translates to:
  /// **'Deleted {name}'**
  String menuCategoryDeleted({required String name});

  /// Categories screen: title when there are no categories
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get menuCategoriesEmptyTitle;

  /// Categories screen: explanation under the empty title
  ///
  /// In en, this message translates to:
  /// **'Categories group your dishes on the POS, on One Local and on your storefront.'**
  String get menuCategoriesEmptyMessage;

  /// Categories screen: floating button
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get menuAddCategory;

  /// Categories screen: line above the list for someone who may reorder
  ///
  /// In en, this message translates to:
  /// **'Drag to change the order everyone sees: the POS, One Local and your storefront.'**
  String get menuCategoriesDragHint;

  /// Categories screen: line above the list for someone who may only look
  ///
  /// In en, this message translates to:
  /// **'The order everyone sees: the POS, One Local and your storefront.'**
  String get menuCategoriesOrderHint;

  /// Categories screen: screen-reader label of the drag handle
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get menuDragToReorder;

  /// Categories screen: how many dishes a category holds
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 dish} other{{count} dishes}}'**
  String menuDishCount({required int count});

  /// Categories screen: tooltip of the three-dot button on a category row; {name} is the category name
  ///
  /// In en, this message translates to:
  /// **'More for {name}'**
  String menuCategoryMoreFor({required String name});

  /// Categories screen: row menu entry that renames a category
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get menuRename;

  /// Categories screen: label of the name field in the new / rename dialog
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get menuCategoryName;

  /// Item editor, storefront card: title when the storefront draft could not be read
  ///
  /// In en, this message translates to:
  /// **'Storefront details could not be loaded'**
  String get menuStorefrontLoadFailedTitle;

  /// Item editor, storefront card: heading of the tag chips
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get menuTagsTitle;

  /// Item editor, storefront card: explanation under the Tags heading
  ///
  /// In en, this message translates to:
  /// **'Small labels on the dish card. \"Bestseller\" also comes from the switch above.'**
  String get menuTagsHint;

  /// Storefront tag chip on a dish card
  ///
  /// In en, this message translates to:
  /// **'Spicy'**
  String get menuTagSpicy;

  /// Storefront tag chip on a dish card
  ///
  /// In en, this message translates to:
  /// **'Chef\'s special'**
  String get menuTagChefsSpecial;

  /// Storefront tag chip on a dish card
  ///
  /// In en, this message translates to:
  /// **'Seasonal'**
  String get menuTagSeasonal;

  /// Storefront tag chip on a dish card: a newly added dish
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get menuTagNew;

  /// Storefront tag chip on a dish card
  ///
  /// In en, this message translates to:
  /// **'Vegan'**
  String get menuTagVegan;

  /// Storefront tag chip on a dish card: suitable for Jain diet
  ///
  /// In en, this message translates to:
  /// **'Jain'**
  String get menuTagJain;

  /// Storefront tag chip on a dish card
  ///
  /// In en, this message translates to:
  /// **'Gluten-free'**
  String get menuTagGlutenFree;

  /// Item editor, storefront card: heading of the ingredient list
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get menuIngredientsTitle;

  /// Item editor, storefront card: explanation under the Ingredients heading
  ///
  /// In en, this message translates to:
  /// **'Type one and tap Add.'**
  String get menuIngredientsHint;

  /// Item editor, storefront card: placeholder of the ingredient field
  ///
  /// In en, this message translates to:
  /// **'Ingredient'**
  String get menuIngredientHint;

  /// Item editor, storefront card: tooltip of the plus button next to the ingredient field
  ///
  /// In en, this message translates to:
  /// **'Add ingredient'**
  String get menuIngredientAdd;

  /// Item editor, storefront card, read-only view: shown when a dish has no ingredients
  ///
  /// In en, this message translates to:
  /// **'None added'**
  String get menuNoneAdded;

  /// Item editor, storefront card: heading of the allergen chips
  ///
  /// In en, this message translates to:
  /// **'Allergens'**
  String get menuAllergensTitle;

  /// Item editor, storefront card: explanation under the Allergens heading
  ///
  /// In en, this message translates to:
  /// **'Guests with allergies look for these first.'**
  String get menuAllergensHint;

  /// Allergen quick-pick chip
  ///
  /// In en, this message translates to:
  /// **'Gluten'**
  String get menuAllergenGluten;

  /// Allergen quick-pick chip
  ///
  /// In en, this message translates to:
  /// **'Dairy'**
  String get menuAllergenDairy;

  /// Allergen quick-pick chip
  ///
  /// In en, this message translates to:
  /// **'Egg'**
  String get menuAllergenEgg;

  /// Allergen quick-pick chip
  ///
  /// In en, this message translates to:
  /// **'Nuts'**
  String get menuAllergenNuts;

  /// Allergen quick-pick chip: almonds, cashews and similar
  ///
  /// In en, this message translates to:
  /// **'Tree nuts'**
  String get menuAllergenTreeNuts;

  /// Allergen quick-pick chip
  ///
  /// In en, this message translates to:
  /// **'Peanuts'**
  String get menuAllergenPeanuts;

  /// Allergen quick-pick chip
  ///
  /// In en, this message translates to:
  /// **'Soy'**
  String get menuAllergenSoy;

  /// Allergen quick-pick chip
  ///
  /// In en, this message translates to:
  /// **'Sesame'**
  String get menuAllergenSesame;

  /// Allergen quick-pick chip
  ///
  /// In en, this message translates to:
  /// **'Shellfish'**
  String get menuAllergenShellfish;

  /// Allergen quick-pick chip
  ///
  /// In en, this message translates to:
  /// **'Fish'**
  String get menuAllergenFish;

  /// Allergen quick-pick chip
  ///
  /// In en, this message translates to:
  /// **'Mustard'**
  String get menuAllergenMustard;

  /// Item editor, storefront card: placeholder of the custom allergen field
  ///
  /// In en, this message translates to:
  /// **'Another allergen'**
  String get menuAllergenAnother;

  /// Item editor, storefront card: tooltip of the plus button next to the allergen field
  ///
  /// In en, this message translates to:
  /// **'Add allergen'**
  String get menuAllergenAdd;

  /// Item editor, storefront card: label of the calories field
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get menuCalories;

  /// Item editor, storefront card: helper text under the calories field
  ///
  /// In en, this message translates to:
  /// **'Optional. Shown when nutrition is switched on.'**
  String get menuCaloriesHint;

  /// Item editor, storefront card: title of the switch that hides the dish from guests
  ///
  /// In en, this message translates to:
  /// **'Hide from storefront'**
  String get menuHideFromStorefront;

  /// Item editor, storefront card: subtitle of the hide switch
  ///
  /// In en, this message translates to:
  /// **'Still sold in the POS and on One Local'**
  String get menuHideFromStorefrontHint;

  /// Item editor, storefront card: footnote for someone who may edit the storefront; Studio is the storefront editor screen
  ///
  /// In en, this message translates to:
  /// **'Shows on your storefront after you publish in Studio.'**
  String get menuStorefrontPublishNote;

  /// Item editor, storefront card: footnote for someone who may only look
  ///
  /// In en, this message translates to:
  /// **'Only owners, admins, managers and marketing can change these.'**
  String get menuStorefrontReadOnlyNote;

  /// Failure code menu_category_name_needed: saving a category with an empty name
  ///
  /// In en, this message translates to:
  /// **'Give the category a name.'**
  String get menuFailCategoryNameNeeded;

  /// Failure code menu_category_not_removed: delete changed nothing
  ///
  /// In en, this message translates to:
  /// **'That category could not be removed. It may already be gone.'**
  String get menuFailCategoryNotRemoved;

  /// Failure code menu_item_name_needed: saving a dish with an empty name
  ///
  /// In en, this message translates to:
  /// **'Give the item a name.'**
  String get menuFailItemNameNeeded;

  /// Failure code menu_price_negative: saving a dish with a price below zero
  ///
  /// In en, this message translates to:
  /// **'Price cannot be negative.'**
  String get menuFailPriceNegative;

  /// Failure code menu_item_gone: availability change found no such dish
  ///
  /// In en, this message translates to:
  /// **'That item no longer exists.'**
  String get menuFailItemGone;

  /// Failure code menu_storefront_not_loaded: item editor could not read the storefront draft
  ///
  /// In en, this message translates to:
  /// **'The storefront could not be loaded.'**
  String get menuFailStorefrontNotLoaded;

  /// Failure code menu_photo_picker: the phone refused camera or photo-library access
  ///
  /// In en, this message translates to:
  /// **'Could not open the camera or photos. Allow access in the phone settings and try again.'**
  String get menuFailPhotoPicker;

  /// Title of the Table QR codes screen (app bar)
  ///
  /// In en, this message translates to:
  /// **'Table QR codes'**
  String get tableScreenTitle;

  /// App bar button on the Table QR codes screen: prints an A4 sheet with every coded table in use
  ///
  /// In en, this message translates to:
  /// **'Print all'**
  String get tablePrintAll;

  /// Empty-state title when the signed-in role may not see table codes
  ///
  /// In en, this message translates to:
  /// **'Not available for your role'**
  String get tableBlockedTitle;

  /// Empty-state line under 'Not available for your role' on the Table QR codes screen
  ///
  /// In en, this message translates to:
  /// **'Ask an owner or admin for the table codes.'**
  String get tableBlockedMessage;

  /// Loading label on the Table QR codes screen
  ///
  /// In en, this message translates to:
  /// **'Loading tables…'**
  String get tableLoading;

  /// Empty-state title when the restaurant has no tables
  ///
  /// In en, this message translates to:
  /// **'No tables yet'**
  String get tableEmptyTitle;

  /// Empty-state line when the restaurant has no tables; VINII is the product name
  ///
  /// In en, this message translates to:
  /// **'Add your tables in the VINII control panel. Each one gets its own QR code here.'**
  String get tableEmptyMessage;

  /// Intro line at the top of the Table QR codes list; {withCode} is how many tables already have a code, {total} how many tables there are
  ///
  /// In en, this message translates to:
  /// **'Guests scan a table\'s code to order from that table. {withCode} of {total} {total, plural, =1{table has} other{tables have}} a code.'**
  String tableIntro({required int withCode, required int total});

  /// Heading of a floor section with the number of tables in it; {name} is the section name the owner typed (e.g. Indoor)
  ///
  /// In en, this message translates to:
  /// **'{name} · {count}'**
  String tableGroupHeader({required String name, required int count});

  /// Small status chip on a table that is switched off
  ///
  /// In en, this message translates to:
  /// **'Not in use'**
  String get tableNotInUse;

  /// How many seats a table has
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 seat} other{{count} seats}}'**
  String tableSeats({required int count});

  /// Shown on a table that has no QR code issued
  ///
  /// In en, this message translates to:
  /// **'No code yet'**
  String get tableNoCode;

  /// Button: issue the first QR code for a table
  ///
  /// In en, this message translates to:
  /// **'Issue code'**
  String get tableIssueCode;

  /// Shown instead of the Issue code button when this role may not issue codes
  ///
  /// In en, this message translates to:
  /// **'An admin or manager can issue it.'**
  String get tableIssueHint;

  /// Small button on a table that has a code: replace it with a new code
  ///
  /// In en, this message translates to:
  /// **'New code'**
  String get tableNewCode;

  /// Tile button under a table's QR code: copy the guest link
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get tableCopyLink;

  /// Tile button under a table's QR code: download the QR card as a picture
  ///
  /// In en, this message translates to:
  /// **'Save image'**
  String get tableSaveImage;

  /// Screen-reader label of a table's QR code picture; {table} is the table name
  ///
  /// In en, this message translates to:
  /// **'QR code for {table}'**
  String tableQrSemantics({required String table});

  /// Snackbar after the QR card picture was saved
  ///
  /// In en, this message translates to:
  /// **'Saved the picture for {table}.'**
  String tableImageSaved({required String table});

  /// Snackbar after the guest link was copied
  ///
  /// In en, this message translates to:
  /// **'Link for {table} copied.'**
  String tableLinkCopied({required String table});

  /// Snackbar after the first code was issued
  ///
  /// In en, this message translates to:
  /// **'Code issued for {table}. Print its sticker.'**
  String tableCodeIssued({required String table});

  /// Snackbar after a code was replaced
  ///
  /// In en, this message translates to:
  /// **'New code for {table}. Print its new sticker.'**
  String tableCodeReplaced({required String table});

  /// Title of the confirm dialog before replacing a table's QR code
  ///
  /// In en, this message translates to:
  /// **'Replace the code for {table}?'**
  String tableReplaceTitle({required String table});

  /// Warning in the confirm dialog before replacing a table's QR code
  ///
  /// In en, this message translates to:
  /// **'Printed stickers will stop working. Guests who scan the old code will not reach this table. Only do this if the sticker was lost or shared by mistake.'**
  String get tableReplaceBody;

  /// Dialog button: do not replace the code
  ///
  /// In en, this message translates to:
  /// **'Keep the code'**
  String get tableReplaceKeep;

  /// Dialog button (red): replace the QR code now
  ///
  /// In en, this message translates to:
  /// **'Replace code'**
  String get tableReplaceConfirm;

  /// Printed under the QR code when the organisation name is not known
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get tableRestaurantFallback;

  /// Name of the printed sheet (print dialog, PDF title); {restaurant} is the restaurant name
  ///
  /// In en, this message translates to:
  /// **'Table QR codes - {restaurant}'**
  String tablePrintTitle({required String restaurant});

  /// Line printed on the guest QR card under the table and restaurant name (guest-facing; drawn into the card picture and the A4 sheet)
  ///
  /// In en, this message translates to:
  /// **'Scan to see the menu and order'**
  String get tableCardScan;

  /// Failure table_save_browser_only: this device cannot download the QR picture
  ///
  /// In en, this message translates to:
  /// **'Saving the picture works in the browser for now. On a phone, use Print all, or take a screenshot of the code.'**
  String get tableFailSaveBrowserOnly;

  /// Failure table_picture_not_saved
  ///
  /// In en, this message translates to:
  /// **'The picture could not be saved. Try again.'**
  String get tableFailPictureNotSaved;

  /// Failure table_sheet_not_printed
  ///
  /// In en, this message translates to:
  /// **'The sheet was not printed. Check the printer and try again.'**
  String get tableFailSheetNotPrinted;

  /// Failure table_issue_forbidden
  ///
  /// In en, this message translates to:
  /// **'Only an admin or manager can issue table codes.'**
  String get tableFailIssueForbidden;

  /// Failure table_issue_busy: a code for this table is already being issued
  ///
  /// In en, this message translates to:
  /// **'Already working on it…'**
  String get tableFailBusy;

  /// Failure table_list_not_ready: the tables table is missing on the server
  ///
  /// In en, this message translates to:
  /// **'Tables are not set up in this database yet.'**
  String get tableFailListNotReady;

  /// Failure table_issue_not_ready: the issue-code database function is not installed yet; VINII is the product name
  ///
  /// In en, this message translates to:
  /// **'Issuing table codes from the phone needs a database update that is waiting for approval. Until then, issue codes from the VINII control panel.'**
  String get tableFailIssueNotReady;

  /// Failure table_bad_shape
  ///
  /// In en, this message translates to:
  /// **'The server sent a table in a shape this app does not understand.'**
  String get tableFailBadShape;

  /// Failure table_no_code_returned
  ///
  /// In en, this message translates to:
  /// **'The server did not send back a code. Try again.'**
  String get tableFailNoCode;

  /// Empty-state title when the signed-in role may not see the bill settings
  ///
  /// In en, this message translates to:
  /// **'Not available for your role'**
  String get billBlockedTitle;

  /// Empty-state line on the Bill & GST screen for a role that may not look
  ///
  /// In en, this message translates to:
  /// **'Ask an owner or admin to look at the bill settings.'**
  String get billBlockedMessage;

  /// Loading label on the Bill & GST screen
  ///
  /// In en, this message translates to:
  /// **'Loading bill settings…'**
  String get billLoading;

  /// Banner at the top of Bill & GST for roles that can look but not edit
  ///
  /// In en, this message translates to:
  /// **'Only an owner or admin can change this.'**
  String get billNoticeReadOnly;

  /// Banner on Bill & GST when the organisation has no saved settings; {percent} is the standard GST rate as a plain number (5)
  ///
  /// In en, this message translates to:
  /// **'No bill settings are saved yet, so bills use the standard {percent}% GST. Change anything below, then save.'**
  String billNoticeNoSettings({required String percent});

  /// Section title and the label of the custom rate box on Bill & GST
  ///
  /// In en, this message translates to:
  /// **'GST rate'**
  String get billGstRate;

  /// Helper line under the GST rate title
  ///
  /// In en, this message translates to:
  /// **'Added to every bill, on the food and on the service charge.'**
  String get billGstRateHelp;

  /// A percentage choice on a segmented control; {percent} is a plain number (5, 12, 7.5)
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String billPercent({required String percent});

  /// Last choice of the GST rate control: type your own rate
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get billCustom;

  /// Hint inside the custom GST rate box
  ///
  /// In en, this message translates to:
  /// **'e.g. 12.5'**
  String get billCustomGstHint;

  /// How the GST rate is split on the bill; {cgst} and {sgst} are plain numbers (2.5)
  ///
  /// In en, this message translates to:
  /// **'CGST {cgst}% + SGST {sgst}%'**
  String billGstSplit({required String cgst, required String sgst});

  /// Label of the GST identification number box (acronym stays Latin)
  ///
  /// In en, this message translates to:
  /// **'GSTIN'**
  String get billGstin;

  /// Helper text under the GSTIN box
  ///
  /// In en, this message translates to:
  /// **'Printed on every bill'**
  String get billGstinHelper;

  /// Title of the service charge ON/OFF row
  ///
  /// In en, this message translates to:
  /// **'Service charge'**
  String get billServiceCharge;

  /// Helper line under the service charge ON/OFF row
  ///
  /// In en, this message translates to:
  /// **'Added before GST. Staff can remove it from a bill at the final order.'**
  String get billServiceChargeHelp;

  /// Label of the service charge percentage box
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get billPercentage;

  /// Hint inside the service charge percentage box
  ///
  /// In en, this message translates to:
  /// **'e.g. 10'**
  String get billServicePercentHint;

  /// Helper under the service charge percentage box; {max} is the highest allowed percentage (50)
  ///
  /// In en, this message translates to:
  /// **'Up to {max}%'**
  String billServicePercentHelper({required String max});

  /// Title of the rounding ON/OFF row
  ///
  /// In en, this message translates to:
  /// **'Round the final bill to the nearest rupee'**
  String get billRoundTitle;

  /// Helper line under the rounding ON/OFF row
  ///
  /// In en, this message translates to:
  /// **'For example, ₹553.46 becomes ₹553.'**
  String get billRoundHelp;

  /// Section label above the legal name, address, phone, FSSAI and footer boxes
  ///
  /// In en, this message translates to:
  /// **'On the printed bill'**
  String get billSectionPrinted;

  /// Label of the registered business name box
  ///
  /// In en, this message translates to:
  /// **'Legal name'**
  String get billLegalName;

  /// Hint inside the legal name box
  ///
  /// In en, this message translates to:
  /// **'Your registered business name'**
  String get billLegalNameHint;

  /// Label of the phone box printed on the bill
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get billPhone;

  /// Label of the food licence number box (FSSAI is an acronym)
  ///
  /// In en, this message translates to:
  /// **'FSSAI number'**
  String get billFssai;

  /// Helper text under the FSSAI number box
  ///
  /// In en, this message translates to:
  /// **'14 digits'**
  String get billFssaiHelper;

  /// Label of the text printed at the bottom of every bill
  ///
  /// In en, this message translates to:
  /// **'Footer note'**
  String get billFooter;

  /// Example text inside the footer note box
  ///
  /// In en, this message translates to:
  /// **'Thank you! Visit again.'**
  String get billFooterHint;

  /// Title of the example bill card; {amount} is a rupee amount such as ₹1,000
  ///
  /// In en, this message translates to:
  /// **'Example: {amount} of food'**
  String billExampleTitle({required String amount});

  /// Helper line under the example bill title
  ///
  /// In en, this message translates to:
  /// **'Changes as you edit the settings.'**
  String get billExampleHelp;

  /// Label of the total line of the example bill
  ///
  /// In en, this message translates to:
  /// **'Guest pays'**
  String get billGuestPays;

  /// Status in the bottom bar when another person saved first
  ///
  /// In en, this message translates to:
  /// **'Someone else saved these settings while you were editing. Reload to see their changes. Your edits here will be replaced.'**
  String get billStale;

  /// Status in the bottom bar when a field has a problem
  ///
  /// In en, this message translates to:
  /// **'Fix the highlighted fields to save.'**
  String get billFixFields;

  /// Status in the bottom bar when edits are waiting to be saved
  ///
  /// In en, this message translates to:
  /// **'You have changes that are not saved yet.'**
  String get billUnsaved;

  /// Status in the bottom bar right after saving
  ///
  /// In en, this message translates to:
  /// **'All changes saved.'**
  String get billAllSaved;

  /// Status in the bottom bar when the organisation has never saved bill settings
  ///
  /// In en, this message translates to:
  /// **'Not saved yet.'**
  String get billNotSaved;

  /// Status in the bottom bar when the saved time is unknown
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get billSavedPlain;

  /// Status in the bottom bar when saved today; {time} is a clock time such as 4:15 PM
  ///
  /// In en, this message translates to:
  /// **'Last saved at {time}'**
  String billLastSavedAt({required String time});

  /// Status in the bottom bar when saved on an earlier day; {day} is like Sat, 3 Oct and {time} like 4:15 PM
  ///
  /// In en, this message translates to:
  /// **'Last saved {day}, {time}'**
  String billLastSavedOn({required String day, required String time});

  /// Button in the bottom bar when another person saved first: load their version
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get billReload;

  /// Button in the bottom bar: save the bill settings
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get billSaveChanges;

  /// Snackbar after the bill settings were saved
  ///
  /// In en, this message translates to:
  /// **'Bill settings saved.'**
  String get billSaved;

  /// Error under the custom GST rate box
  ///
  /// In en, this message translates to:
  /// **'Enter a rate from 0 to 100, like 5 or 12.5.'**
  String get billProblemCustomRate;

  /// Error under the service charge percentage box; {max} is the highest allowed percentage (50)
  ///
  /// In en, this message translates to:
  /// **'Enter a percentage above 0 and up to {max}, or switch the service charge off.'**
  String billProblemService({required String max});

  /// Error under the GSTIN box
  ///
  /// In en, this message translates to:
  /// **'A GSTIN has 15 letters and numbers, like 22AAAAA0000A1Z5.'**
  String get billProblemGstin;

  /// Error under the FSSAI number box
  ///
  /// In en, this message translates to:
  /// **'An FSSAI number has 14 digits.'**
  String get billProblemFssai;

  /// Error under the phone box
  ///
  /// In en, this message translates to:
  /// **'Enter a phone number with at least 10 digits.'**
  String get billProblemPhone;

  /// Failure bill_not_ready: the bill settings table is missing on the server
  ///
  /// In en, this message translates to:
  /// **'Bill settings are not set up in this database yet.'**
  String get billFailNotReady;

  /// Failure bill_conflict: the saved row changed since this screen loaded it
  ///
  /// In en, this message translates to:
  /// **'Someone else saved these settings while you were editing. Reload to see their changes, then make yours again.'**
  String get billFailConflict;

  /// Failure bill_not_saved: the write changed nothing and no newer row exists, so the server refused it
  ///
  /// In en, this message translates to:
  /// **'These settings were not saved. You may not have permission to change them.'**
  String get billFailNotSaved;

  /// Title of the Storefront Studio screens (the owner's editor for the guest ordering site)
  ///
  /// In en, this message translates to:
  /// **'Storefront Studio'**
  String get studioTitle;

  /// Studio home: shown while the storefront loads
  ///
  /// In en, this message translates to:
  /// **'Opening your storefront…'**
  String get studioOpening;

  /// Banner at the top of Studio and the reason publishing/restoring is refused while the database tables are missing
  ///
  /// In en, this message translates to:
  /// **'Publishing needs the storefront tables, a database update waiting for approval. Your draft is kept on this phone until then.'**
  String get studioNoteDraftOnPhone;

  /// Banner on Studio home when a reload failed; {reason} is the failure sentence
  ///
  /// In en, this message translates to:
  /// **'Could not refresh. {reason}'**
  String studioRefreshFailed({required String reason});

  /// Banner on Studio home for a role that may only view the storefront
  ///
  /// In en, this message translates to:
  /// **'You can look around. Owners, admins, managers and marketing can change the storefront.'**
  String get studioReadOnlyHome;

  /// Banner on a Studio section for a role that may only view the storefront
  ///
  /// In en, this message translates to:
  /// **'You can look, but only owners, admins, managers and marketing can change this.'**
  String get studioReadOnlySection;

  /// Heading above the phone preview on Studio home
  ///
  /// In en, this message translates to:
  /// **'Live preview'**
  String get studioLivePreviewLabel;

  /// Studio home: heading of the group of sections about how the storefront looks
  ///
  /// In en, this message translates to:
  /// **'Look'**
  String get studioGroupLook;

  /// Studio home: heading of the group of sections about how guests order
  ///
  /// In en, this message translates to:
  /// **'Ordering'**
  String get studioGroupOrdering;

  /// Studio home: heading of the group with the share link and version history
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get studioGroupShare;

  /// Studio section title: choose the template, accent colour and category style
  ///
  /// In en, this message translates to:
  /// **'Template & colour'**
  String get studioSectionLook;

  /// Studio section title: restaurant name and welcome words
  ///
  /// In en, this message translates to:
  /// **'Brand & welcome'**
  String get studioSectionBrand;

  /// Studio section title: dine-in, takeaway, pre-order, delivery
  ///
  /// In en, this message translates to:
  /// **'How guests order'**
  String get studioSectionService;

  /// Studio section title: switches for the guest experience (budget, likes, tracking...)
  ///
  /// In en, this message translates to:
  /// **'Guest features'**
  String get studioSectionFeatures;

  /// Studio section title: which menu categories guests see and in what order
  ///
  /// In en, this message translates to:
  /// **'Menu on the storefront'**
  String get studioSectionCategories;

  /// Studio section title: chef's picks and limited-time offers
  ///
  /// In en, this message translates to:
  /// **'Chef\'s picks & offers'**
  String get studioSectionHighlights;

  /// Studio section title: the storefront address and its QR code
  ///
  /// In en, this message translates to:
  /// **'Share & QR code'**
  String get studioSectionShare;

  /// Studio section title: published versions that can be restored
  ///
  /// In en, this message translates to:
  /// **'Versions'**
  String get studioSectionHistory;

  /// Studio home: one-line state of the Template & colour section; template name, accent colour code, category style name
  ///
  /// In en, this message translates to:
  /// **'{template} · {accent} · {style}'**
  String studioSummaryLook({
    required String template,
    required String accent,
    required String style,
  });

  /// Studio home summary of Brand & welcome when the display name is empty
  ///
  /// In en, this message translates to:
  /// **'No name yet'**
  String get studioSummaryNoName;

  /// Studio home summary of Brand & welcome when there is no welcome headline; follows the restaurant name
  ///
  /// In en, this message translates to:
  /// **'no welcome headline yet'**
  String get studioSummaryNoHeadline;

  /// Studio home summary of How guests order when no way to order is on
  ///
  /// In en, this message translates to:
  /// **'Nothing switched on'**
  String get studioSummaryNothingOn;

  /// Studio home summary of Guest features; {style} is swipe cards or scrolling list
  ///
  /// In en, this message translates to:
  /// **'{on} of {total} on · {style}'**
  String studioSummaryFeatures({
    required int on,
    required int total,
    required String style,
  });

  /// Part of the Guest features summary: guests browse dishes as swipe cards
  ///
  /// In en, this message translates to:
  /// **'swipe cards'**
  String get studioSummaryDeckSwipe;

  /// Part of the Guest features summary: guests browse dishes as a scrolling list
  ///
  /// In en, this message translates to:
  /// **'scrolling list'**
  String get studioSummaryDeckList;

  /// Studio home summary of Menu on the storefront
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total} categories shown'**
  String studioSummaryCategoriesShown({required int shown, required int total});

  /// Studio home summary of Chef's picks & offers when nothing is chosen
  ///
  /// In en, this message translates to:
  /// **'None chosen yet'**
  String get studioSummaryHighlightsNone;

  /// Studio home summary of Chef's picks & offers; number of picks and of limited-today offers
  ///
  /// In en, this message translates to:
  /// **'{picks, plural, =1{1 chef\'s pick} other{{picks} chef\'s picks}} · {offers} limited today'**
  String studioSummaryHighlights({required int picks, required int offers});

  /// Studio home summary of Versions, and the title of the empty Versions screen
  ///
  /// In en, this message translates to:
  /// **'Nothing published yet'**
  String get studioNothingPublished;

  /// Studio home summary of Versions; the live version number and how many versions are kept
  ///
  /// In en, this message translates to:
  /// **'Version {live} is live · {count, plural, =1{1 version} other{{count} versions}} kept'**
  String studioSummaryHistory({required int live, required int count});

  /// Status card on Studio home: the storefront was never published
  ///
  /// In en, this message translates to:
  /// **'Not published yet'**
  String get studioStatusNotPublished;

  /// Status card on Studio home; {date} is a day and month such as 3 Oct
  ///
  /// In en, this message translates to:
  /// **'Live · version {version} · published {date}'**
  String studioStatusLive({required int version, required String date});

  /// Status card on Studio home; {by} is the staff member who published
  ///
  /// In en, this message translates to:
  /// **'Live · version {version} · published {date} by {by}'**
  String studioStatusLiveBy({
    required int version,
    required String date,
    required String by,
  });

  /// Chip on the status card: guests cannot see the storefront yet
  ///
  /// In en, this message translates to:
  /// **'Not live yet'**
  String get studioChipNotLive;

  /// Chip: this version is what guests see now
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get studioLive;

  /// Chip on the status card: edits not yet saved as a draft
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get studioChipUnsaved;

  /// Chip on the status card: a saved draft differs from what guests see
  ///
  /// In en, this message translates to:
  /// **'Unpublished changes'**
  String get studioChipUnpublished;

  /// Tooltip and button: copy the storefront web address
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get studioCopyAddress;

  /// Confirmation after copying the storefront web address
  ///
  /// In en, this message translates to:
  /// **'Address copied'**
  String get studioAddressCopied;

  /// Note under the storefront address on Studio home
  ///
  /// In en, this message translates to:
  /// **'This web address works once the VINII guest website is live. Until then, try it in the preview below.'**
  String get studioAddressNote;

  /// Text above the phone preview on Studio home
  ///
  /// In en, this message translates to:
  /// **'This is what guests see on their phone. Every change shows here straight away.'**
  String get studioPreviewIntro;

  /// Banner above the phone preview when the menu has nothing orderable
  ///
  /// In en, this message translates to:
  /// **'No dishes guests can order yet. Add dishes with a price in the Menu tab.'**
  String get studioPreviewNoDishes;

  /// Button, menu item and tooltip: open the full-screen guest preview
  ///
  /// In en, this message translates to:
  /// **'Open full preview'**
  String get studioOpenFullPreview;

  /// Note under the Open full preview button
  ///
  /// In en, this message translates to:
  /// **'Try ordering in the full preview. Nothing is sent to the kitchen.'**
  String get studioPreviewTryNote;

  /// Accessibility label of the phone frame showing the storefront preview
  ///
  /// In en, this message translates to:
  /// **'Preview of your storefront'**
  String get studioPreviewFrame;

  /// Button: save the Studio edits as a draft
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get studioSaveDraft;

  /// Button: publish the storefront so guests see it
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get studioPublish;

  /// Menu item and button: throw away the Studio edits
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get studioDiscardChanges;

  /// Confirmation after saving the draft
  ///
  /// In en, this message translates to:
  /// **'Draft saved'**
  String get studioDraftSaved;

  /// Confirmation after saving the draft when the database tables are missing so it stays on the phone
  ///
  /// In en, this message translates to:
  /// **'Draft saved on this phone'**
  String get studioDraftSavedOnPhone;

  /// Confirmation after publishing
  ///
  /// In en, this message translates to:
  /// **'Published version {version}'**
  String studioPublishedVersion({required int version});

  /// Dialog title when publishing is refused because the database update is missing
  ///
  /// In en, this message translates to:
  /// **'Publishing is not available yet'**
  String get studioPublishUnavailable;

  /// Dialog title: confirm throwing away Studio edits
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get studioDiscardTitle;

  /// Discard dialog text when nothing was ever published
  ///
  /// In en, this message translates to:
  /// **'Studio goes back to a blank storefront with your restaurant name.'**
  String get studioDiscardBodyBlank;

  /// Discard dialog text when a version is live
  ///
  /// In en, this message translates to:
  /// **'Studio goes back to what guests see now (version {version}).'**
  String studioDiscardBodyLive({required int version});

  /// Discard dialog button: keep the edits
  ///
  /// In en, this message translates to:
  /// **'Keep them'**
  String get studioDiscardKeep;

  /// Discard dialog button: throw the edits away
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get studioDiscardConfirm;

  /// Confirmation after discarding Studio edits
  ///
  /// In en, this message translates to:
  /// **'Changes discarded'**
  String get studioDiscarded;

  /// Sheet title when publishing is blocked until some problems are fixed
  ///
  /// In en, this message translates to:
  /// **'Almost ready to publish'**
  String get studioProblemsTitle;

  /// Sheet text above the list of problems that block publishing
  ///
  /// In en, this message translates to:
  /// **'Fix these first, so guests never land on a broken page:'**
  String get studioProblemsIntro;

  /// Failure studio_not_loaded: an action ran before the storefront loaded
  ///
  /// In en, this message translates to:
  /// **'The storefront has not loaded yet.'**
  String get studioNotLoaded;

  /// Publish problem studio_problem_name; names the Brand & welcome section
  ///
  /// In en, this message translates to:
  /// **'Add your restaurant\'s name in Brand & welcome.'**
  String get studioProblemName;

  /// Publish problem studio_problem_modes; names the How guests order section
  ///
  /// In en, this message translates to:
  /// **'Turn on at least one way to order in How guests order.'**
  String get studioProblemModes;

  /// Publish problem studio_problem_budget; names the Guest features section
  ///
  /// In en, this message translates to:
  /// **'Budget amounts need minimum ≤ starting amount ≤ maximum, in Guest features.'**
  String get studioProblemBudget;

  /// Publish problem studio_problem_preorder
  ///
  /// In en, this message translates to:
  /// **'Pre-order has no pickup times: the closing time must be at least one slot after the opening time.'**
  String get studioProblemPreOrder;

  /// Publish problem studio_problem_empty_menu
  ///
  /// In en, this message translates to:
  /// **'Guests would see an empty menu. Add dishes with a price in the Menu tab, keep them available, and keep at least one category visible.'**
  String get studioProblemEmptyMenu;

  /// Sheet title of the publish confirmation
  ///
  /// In en, this message translates to:
  /// **'Publish version {next}?'**
  String studioConfirmTitle({required int next});

  /// Publish confirmation sheet text
  ///
  /// In en, this message translates to:
  /// **'Every guest who opens your storefront sees this straight away.'**
  String get studioConfirmIntro;

  /// Publish confirmation: the list of changes is empty
  ///
  /// In en, this message translates to:
  /// **'Nothing guests see has changed.'**
  String get studioConfirmNoChange;

  /// Publish confirmation: heading above the list of changes
  ///
  /// In en, this message translates to:
  /// **'What guests will see change'**
  String get studioConfirmWhatChanges;

  /// Publish confirmation button
  ///
  /// In en, this message translates to:
  /// **'Publish now'**
  String get studioConfirmNow;

  /// Publish confirmation button: do not publish
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get studioConfirmLater;

  /// Publish confirmation line: nothing was published before
  ///
  /// In en, this message translates to:
  /// **'Your storefront goes live for the first time.'**
  String get studioChangeFirst;

  /// Publish confirmation line: template changes; names of two templates
  ///
  /// In en, this message translates to:
  /// **'Template: {from} → {to}'**
  String studioChangeTemplate({required String from, required String to});

  /// Publish confirmation line: accent colour changes; two colour codes like #F5B82E
  ///
  /// In en, this message translates to:
  /// **'Accent colour: {from} → {to}'**
  String studioChangeAccent({required String from, required String to});

  /// Publish confirmation line: the CMS colours, button style or fonts changed
  ///
  /// In en, this message translates to:
  /// **'Colours, buttons and fonts'**
  String get studioChangeTheme;

  /// Publish confirmation line: category style changes; names of two styles
  ///
  /// In en, this message translates to:
  /// **'Category style: {from} → {to}'**
  String studioChangeCategoryStyle({required String from, required String to});

  /// Publish confirmation line: the display name changed; {name} is what the restaurant typed
  ///
  /// In en, this message translates to:
  /// **'Name: {name}'**
  String studioChangeName({required String name});

  /// Publish confirmation line: the logo changed
  ///
  /// In en, this message translates to:
  /// **'Logo'**
  String get studioChangeLogo;

  /// Publish confirmation line: pictures changed
  ///
  /// In en, this message translates to:
  /// **'Pictures'**
  String get studioChangePictures;

  /// Publish confirmation line: the wording guests read changed
  ///
  /// In en, this message translates to:
  /// **'Guest text'**
  String get studioChangeGuestText;

  /// Publish confirmation line: the language guests start in changed; {language} is its native name
  ///
  /// In en, this message translates to:
  /// **'Guests start in {language}'**
  String studioChangeGuestLanguage({required String language});

  /// Publish confirmation line: the ways to order changed; {modes} is a comma-separated list
  ///
  /// In en, this message translates to:
  /// **'Ways to order: {modes}'**
  String studioChangeModes({required String modes});

  /// Publish confirmation line: the word used for a table changed; {label} is what the restaurant typed
  ///
  /// In en, this message translates to:
  /// **'Table label: \"{label}\"'**
  String studioChangeTableLabel({required String label});

  /// Publish confirmation line: pre-order times changed
  ///
  /// In en, this message translates to:
  /// **'Pre-order times'**
  String get studioChangePreOrder;

  /// Publish confirmation line: which categories guests see changed
  ///
  /// In en, this message translates to:
  /// **'Categories shown to guests'**
  String get studioChangeCategories;

  /// Publish confirmation line: tags and details of some dishes changed
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Storefront details of 1 dish} other{Storefront details of {count} dishes}}'**
  String studioChangeItems({required int count});

  /// Publish confirmation line: the chef's picks changed
  ///
  /// In en, this message translates to:
  /// **'Chef\'s picks'**
  String get studioChangeChefsPicks;

  /// Publish confirmation line: the limited-today offers changed
  ///
  /// In en, this message translates to:
  /// **'Limited today offers'**
  String get studioChangeLimited;

  /// Sheet title when leaving Studio with edits nobody saved
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes'**
  String get studioUnsavedTitle;

  /// Sheet text when leaving Studio with unsaved edits
  ///
  /// In en, this message translates to:
  /// **'Save them as a draft to keep working later, or discard them.'**
  String get studioUnsavedBody;

  /// Button: stay in Studio instead of leaving
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get studioKeepEditing;

  /// Empty-state title for an unknown Studio section link
  ///
  /// In en, this message translates to:
  /// **'This part of Studio does not exist'**
  String get studioSectionMissing;

  /// Button on the unknown-section screen
  ///
  /// In en, this message translates to:
  /// **'Back to Studio'**
  String get studioBackToStudio;

  /// Bottom bar of a Studio section after an edit
  ///
  /// In en, this message translates to:
  /// **'Changes show in the preview. Save or publish them in Studio.'**
  String get studioDoneBarDirty;

  /// Bottom bar of a Studio section before any edit
  ///
  /// In en, this message translates to:
  /// **'Changes show in the preview straight away.'**
  String get studioDoneBarClean;

  /// Label at the top of the full-screen guest preview
  ///
  /// In en, this message translates to:
  /// **'Preview · orders are not sent'**
  String get studioPreviewPill;

  /// Tooltip of the close button of the full preview
  ///
  /// In en, this message translates to:
  /// **'Close preview'**
  String get studioPreviewClose;

  /// Shown while the full preview loads
  ///
  /// In en, this message translates to:
  /// **'Opening the preview…'**
  String get studioPreviewOpening;

  /// Full preview: the signed-in role may not view the storefront
  ///
  /// In en, this message translates to:
  /// **'Your role cannot see the storefront.'**
  String get studioPreviewNoAccess;

  /// Brand & welcome: heading above the welcome-screen sample
  ///
  /// In en, this message translates to:
  /// **'Welcome screen'**
  String get studioBrandWelcomeScreen;

  /// Brand & welcome: heading of the name, tagline and location fields
  ///
  /// In en, this message translates to:
  /// **'Name and place'**
  String get studioBrandNamePlace;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get studioBrandDisplayName;

  /// Helper text under Display name
  ///
  /// In en, this message translates to:
  /// **'How guests see your restaurant'**
  String get studioBrandDisplayNameHelp;

  /// Error under Display name when it is empty
  ///
  /// In en, this message translates to:
  /// **'Guests need to see a name'**
  String get studioBrandNameRequired;

  /// Field label; also a line in the publish confirmation
  ///
  /// In en, this message translates to:
  /// **'Tagline'**
  String get studioBrandTagline;

  /// Helper text under Tagline
  ///
  /// In en, this message translates to:
  /// **'Optional. One short line under your name.'**
  String get studioBrandTaglineHelp;

  /// Field label; also a line in the publish confirmation
  ///
  /// In en, this message translates to:
  /// **'Location line'**
  String get studioBrandLocationLine;

  /// Example text inside the empty Location line field
  ///
  /// In en, this message translates to:
  /// **'Area, City'**
  String get studioBrandLocationHint;

  /// Helper text under Location line
  ///
  /// In en, this message translates to:
  /// **'Optional. Helps guests know they are in the right place.'**
  String get studioBrandLocationHelp;

  /// Brand & welcome: heading of the headline and text fields
  ///
  /// In en, this message translates to:
  /// **'Welcome words'**
  String get studioBrandWelcomeWords;

  /// Field label; also a line in the publish confirmation
  ///
  /// In en, this message translates to:
  /// **'Welcome headline'**
  String get studioBrandHeroTitle;

  /// Field label; also a line in the publish confirmation
  ///
  /// In en, this message translates to:
  /// **'Welcome text'**
  String get studioBrandHeroText;

  /// Note under the welcome fields; {template} is the template name
  ///
  /// In en, this message translates to:
  /// **'The grey words are only an example for the {template} template. Guests see only what you write.'**
  String studioBrandExampleNote({required String template});

  /// Caption on the welcome-screen sample while the headline is empty
  ///
  /// In en, this message translates to:
  /// **'Example headline. Write your own below.'**
  String get studioBrandExampleHeadline;

  /// Heading above the template cards; also the caption of the template's own accent swatch
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get studioLookTemplate;

  /// Caption under the swatch holding the restaurant's brand colour
  ///
  /// In en, this message translates to:
  /// **'Your brand'**
  String get studioLookYourBrand;

  /// Heading above the accent colour swatches
  ///
  /// In en, this message translates to:
  /// **'Accent colour'**
  String get studioLookAccent;

  /// Text above the accent colour swatches
  ///
  /// In en, this message translates to:
  /// **'Buttons, highlights and the budget ring use this colour.'**
  String get studioLookAccentNote;

  /// Accessibility label of a colour swatch; {hex} is a code like #F5B82E
  ///
  /// In en, this message translates to:
  /// **'Colour {hex}'**
  String studioLookSwatch({required String hex});

  /// Accessibility label of a captioned colour swatch; {label} is its caption
  ///
  /// In en, this message translates to:
  /// **'{label} colour {hex}'**
  String studioLookSwatchNamed({required String label, required String hex});

  /// Field label for a typed colour code
  ///
  /// In en, this message translates to:
  /// **'Custom colour'**
  String get studioLookCustomColour;

  /// Helper text under the custom colour field
  ///
  /// In en, this message translates to:
  /// **'Six characters, like the code from your logo file'**
  String get studioLookCustomColourHelp;

  /// Heading above the two category style cards
  ///
  /// In en, this message translates to:
  /// **'Category style'**
  String get studioLookCategoryStyle;

  /// Heading above the note about the web CMS
  ///
  /// In en, this message translates to:
  /// **'More in VINII OS'**
  String get studioLookMoreInOs;

  /// Note on the Template & colour section about the web CMS
  ///
  /// In en, this message translates to:
  /// **'Colours, fonts, pictures and all guest text can also be edited in the VINII OS storefront CMS. Both edit the same draft, and saving here keeps what was set there.'**
  String get studioLookCmsNote;

  /// Line listing what the web CMS has set; {summary} is a list separated by dots
  ///
  /// In en, this message translates to:
  /// **'Set there now: {summary}.'**
  String studioLookSetThere({required String summary});

  /// Part of the CMS summary: number of custom colours
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 custom colour} other{{count} custom colours}}'**
  String studioLookCustomColours({required int count});

  /// Part of the CMS summary: button corner shape; {shape} is pill, rounded or square
  ///
  /// In en, this message translates to:
  /// **'{shape} buttons'**
  String studioLookButtonsShape({required String shape});

  /// Part of the CMS summary: button corner shape and outline style
  ///
  /// In en, this message translates to:
  /// **'{shape} outlined buttons'**
  String studioLookButtonsShapeOutlined({required String shape});

  /// Part of the CMS summary: outline buttons with the template's corners
  ///
  /// In en, this message translates to:
  /// **'outlined buttons'**
  String get studioLookButtonsOutlined;

  /// Part of the CMS summary: buttons set in the CMS with no shape or outline
  ///
  /// In en, this message translates to:
  /// **'buttons'**
  String get studioLookButtonsPlain;

  /// Button corner shape: fully round ends; used before the word buttons
  ///
  /// In en, this message translates to:
  /// **'pill'**
  String get studioShapePill;

  /// Button corner shape: softly rounded corners; used before the word buttons
  ///
  /// In en, this message translates to:
  /// **'rounded'**
  String get studioShapeRounded;

  /// Button corner shape: nearly square corners; used before the word buttons
  ///
  /// In en, this message translates to:
  /// **'square'**
  String get studioShapeSquare;

  /// Part of the CMS summary: heading font; {font} is a font name
  ///
  /// In en, this message translates to:
  /// **'{font} headings'**
  String studioLookHeadings({required String font});

  /// Part of the CMS summary: body font; {font} is a font name
  ///
  /// In en, this message translates to:
  /// **'{font} text'**
  String studioLookBodyFont({required String font});

  /// Part of the CMS summary: number of pictures set
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 picture} other{{count} pictures}}'**
  String studioLookPictures({required int count});

  /// Part of the CMS summary; {languages} lists language names
  ///
  /// In en, this message translates to:
  /// **'guest text in {languages}'**
  String studioLookGuestText({required String languages});

  /// Description of the Bistro Night template
  ///
  /// In en, this message translates to:
  /// **'Dark and candle-lit with gold accents. Restaurants, bars, fine dining.'**
  String get studioTemplateBistroNight;

  /// Description of the Artisan Day template
  ///
  /// In en, this message translates to:
  /// **'Warm cream and espresso with a handwritten headline. Bakeries and cafés.'**
  String get studioTemplateArtisanDay;

  /// Description of the Fresh Minimal template
  ///
  /// In en, this message translates to:
  /// **'Clean white and green. Quick service, cloud kitchens, juice bars.'**
  String get studioTemplateFreshMinimal;

  /// Category style: a grid of photo tiles
  ///
  /// In en, this message translates to:
  /// **'Tiles'**
  String get studioStyleTiles;

  /// Hint under the Tiles category style
  ///
  /// In en, this message translates to:
  /// **'A grid of photo tiles'**
  String get studioStyleTilesHint;

  /// Category style: a curved carousel
  ///
  /// In en, this message translates to:
  /// **'Wheel'**
  String get studioStyleWheel;

  /// Hint under the Wheel category style
  ///
  /// In en, this message translates to:
  /// **'A curved carousel guests swipe through'**
  String get studioStyleWheelHint;

  /// Way to order: schedule a pickup for later
  ///
  /// In en, this message translates to:
  /// **'Pre-order'**
  String get studioModePreOrder;

  /// Sheet title for choosing an emoji; {name} is the category name
  ///
  /// In en, this message translates to:
  /// **'Emoji for {name}'**
  String studioCatsEmojiTitle({required String name});

  /// Button: remove the emoji from a category
  ///
  /// In en, this message translates to:
  /// **'No emoji'**
  String get studioCatsNoEmoji;

  /// Empty-state title; also the Studio home summary of Menu on the storefront
  ///
  /// In en, this message translates to:
  /// **'No categories on your menu yet'**
  String get studioCatsNone;

  /// Empty-state text on the Menu on the storefront section
  ///
  /// In en, this message translates to:
  /// **'Add categories and dishes in the Menu tab, then choose here how guests see them.'**
  String get studioCatsNoneMessage;

  /// Button that goes to the Menu tab
  ///
  /// In en, this message translates to:
  /// **'Open Menu'**
  String get studioCatsOpenMenu;

  /// Text above the draggable list of categories
  ///
  /// In en, this message translates to:
  /// **'Drag to set the order guests see. Hidden categories stay on the POS and One Local.'**
  String get studioCatsIntro;

  /// Accessibility label of the drag handle of a category row
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get studioCatsDragHandle;

  /// Accessibility label of the emoji button of a category row
  ///
  /// In en, this message translates to:
  /// **'Choose emoji'**
  String get studioCatsChooseEmoji;

  /// Number of dishes in a category row
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 dish} other{{count} dishes}}'**
  String studioCatsDishCount({required int count});

  /// Category row: guests do not see this category; follows the dish count
  ///
  /// In en, this message translates to:
  /// **'hidden from guests'**
  String get studioCatsHidden;

  /// Banner on the Share & QR code section
  ///
  /// In en, this message translates to:
  /// **'Nothing is published yet, so guests who scan this see nothing. Publish from Studio first.'**
  String get studioShareNotPublished;

  /// Accessibility label of the QR image; {address} is the web address
  ///
  /// In en, this message translates to:
  /// **'QR code for {address}'**
  String studioShareQrSemantics({required String address});

  /// Caption under the QR code on the printable card
  ///
  /// In en, this message translates to:
  /// **'Scan to see the menu and order'**
  String get studioShareScan;

  /// Tip on the Share & QR code section
  ///
  /// In en, this message translates to:
  /// **'Print this QR for tables and the counter.'**
  String get studioSharePrintLine;

  /// Tip on the Share & QR code section
  ///
  /// In en, this message translates to:
  /// **'Per-table QR codes, which open straight to a table, come later.'**
  String get studioSharePerTableLine;

  /// Tip on the Share & QR code section
  ///
  /// In en, this message translates to:
  /// **'The address works once the VINII guest website is live. Until then, use the preview in Studio.'**
  String get studioShareLiveLine;

  /// Dialog title to restore an old version
  ///
  /// In en, this message translates to:
  /// **'Make version {version} live again?'**
  String studioHistoryRestoreTitle({required int version});

  /// Restore dialog text
  ///
  /// In en, this message translates to:
  /// **'Guests will see version {version} again. It is published as version {next}, so nothing is lost.'**
  String studioHistoryRestoreBody({required int version, required int next});

  /// Restore dialog text when Studio holds unpublished changes
  ///
  /// In en, this message translates to:
  /// **'Guests will see version {version} again. It is published as version {next}, so nothing is lost. Your unpublished changes in Studio are replaced by it.'**
  String studioHistoryRestoreBodyUnpublished({
    required int version,
    required int next,
  });

  /// Button: make an older version live again
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get studioRestore;

  /// Confirmation after restoring a version
  ///
  /// In en, this message translates to:
  /// **'Version {version} is live again as version {next}'**
  String studioHistoryRestored({required int version, required int next});

  /// Dialog title when restoring is refused because the database update is missing
  ///
  /// In en, this message translates to:
  /// **'Restoring is not available yet'**
  String get studioHistoryRestoreUnavailable;

  /// Empty-state text on the Versions section
  ///
  /// In en, this message translates to:
  /// **'Each time you publish, a numbered copy is kept here so you can always go back.'**
  String get studioHistoryEmptyMessage;

  /// Text at the top of the Versions list for a role that can restore
  ///
  /// In en, this message translates to:
  /// **'Restore an older version to make it live again.'**
  String get studioHistoryRestoreHint;

  /// Text at the top of the Versions list for a role that cannot restore
  ///
  /// In en, this message translates to:
  /// **'Owners and admins can restore an older version.'**
  String get studioHistoryRestoreHintLocked;

  /// Title of one row in the Versions list
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String studioVersionNumber({required int version});

  /// Who published a version; follows the date
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String studioPublishedBy({required String name});

  /// Studio > Guest features: heading of the group of switches about how guests browse the menu
  ///
  /// In en, this message translates to:
  /// **'Browsing the menu'**
  String get studioFeatGroupBrowse;

  /// Studio > Guest features: heading of the group of switches for guests eating together
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get studioFeatGroupGroups;

  /// Studio > Guest features: heading of the group of switches that apply after the order is placed
  ///
  /// In en, this message translates to:
  /// **'After ordering'**
  String get studioFeatGroupAfter;

  /// Studio > Guest features: heading of the group of switches about what a dish page shows
  ///
  /// In en, this message translates to:
  /// **'Dish details'**
  String get studioFeatGroupDish;

  /// Studio > Guest features: heading of the budget card and title of its switch
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get studioFeatBudgetTitle;

  /// Studio > Guest features: one line under the budget switch
  ///
  /// In en, this message translates to:
  /// **'Guests set how much they want to spend and see what fits.'**
  String get studioFeatBudgetHint;

  /// Studio > Guest features: field label, the lowest budget a guest can set (rupees)
  ///
  /// In en, this message translates to:
  /// **'Minimum'**
  String get studioFeatBudgetMin;

  /// Studio > Guest features: field label, the budget amount the slider starts at (rupees)
  ///
  /// In en, this message translates to:
  /// **'Starts at'**
  String get studioFeatBudgetStart;

  /// Studio > Guest features: field label, the highest budget a guest can set (rupees)
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get studioFeatBudgetMax;

  /// Studio > Guest features: line under the budget fields; {start} and {step} are rupee amounts such as ₹3,000
  ///
  /// In en, this message translates to:
  /// **'Guests start at {start} and move in steps of {step}.'**
  String studioFeatBudgetSummary({required String start, required String step});

  /// Studio > Guest features: red error under the budget fields when the three amounts do not make sense together
  ///
  /// In en, this message translates to:
  /// **'Keep minimum ≤ starts at ≤ maximum, and the minimum above ₹0.'**
  String get studioFeatBudgetInvalid;

  /// Studio > Guest features: switch title
  ///
  /// In en, this message translates to:
  /// **'Swipe cards'**
  String get studioFeatSwipeTitle;

  /// Studio > Guest features: explanation under the Swipe cards switch
  ///
  /// In en, this message translates to:
  /// **'Guests swipe through dishes like cards. Off: a simple scrolling list with Add buttons.'**
  String get studioFeatSwipeHint;

  /// Studio > Guest features: switch title (guests heart a dish to keep it)
  ///
  /// In en, this message translates to:
  /// **'Save for later'**
  String get studioFeatLikesTitle;

  /// Studio > Guest features: explanation under the Save for later switch
  ///
  /// In en, this message translates to:
  /// **'Guests heart dishes and come back to them.'**
  String get studioFeatLikesHint;

  /// Studio: name of the Chef's picks feature; switch title in Guest features and heading in the picks-and-offers screen
  ///
  /// In en, this message translates to:
  /// **'Chef\'s picks'**
  String get studioFeatChefsPicksTitle;

  /// Studio > Guest features: explanation under the Chef's picks switch; the quoted name is the title of another Studio section
  ///
  /// In en, this message translates to:
  /// **'A row of dishes you choose, at the top. Pick them in Chef\'s picks & offers.'**
  String get studioFeatChefsPicksHint;

  /// Studio: name of the Limited today feature (dishes on offer until a set time); switch title and heading
  ///
  /// In en, this message translates to:
  /// **'Limited today'**
  String get studioFeatLimitedTitle;

  /// Studio > Guest features: explanation under the Limited today switch
  ///
  /// In en, this message translates to:
  /// **'Dishes on offer until a time you set, with a countdown.'**
  String get studioFeatLimitedHint;

  /// Studio > Guest features: switch title (budget and bill shown per person)
  ///
  /// In en, this message translates to:
  /// **'Split between people'**
  String get studioFeatSplitPartyTitle;

  /// Studio > Guest features: explanation under the Split between people switch
  ///
  /// In en, this message translates to:
  /// **'Guests say how many are eating; the budget and bill show each share.'**
  String get studioFeatSplitPartyHint;

  /// Studio > Guest features: switch title
  ///
  /// In en, this message translates to:
  /// **'Split the bill'**
  String get studioFeatSplitBillTitle;

  /// Studio > Guest features: explanation under the Split the bill switch
  ///
  /// In en, this message translates to:
  /// **'Guests see the bill divided equally when paying.'**
  String get studioFeatSplitBillHint;

  /// Studio > Guest features: switch title
  ///
  /// In en, this message translates to:
  /// **'Live order tracking'**
  String get studioFeatTrackingTitle;

  /// Studio > Guest features: explanation under the Live order tracking switch
  ///
  /// In en, this message translates to:
  /// **'Guests see when the kitchen starts and finishes their order.'**
  String get studioFeatTrackingHint;

  /// Studio > Guest features: switch title (browse desserts and drinks while the food cooks)
  ///
  /// In en, this message translates to:
  /// **'Discover while waiting'**
  String get studioFeatDiscoverTitle;

  /// Studio > Guest features: explanation under the Discover while waiting switch
  ///
  /// In en, this message translates to:
  /// **'While the food cooks, guests can browse desserts and drinks to add.'**
  String get studioFeatDiscoverHint;

  /// Studio > Guest features: switch title
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get studioFeatFeedbackTitle;

  /// Studio > Guest features: explanation under the Feedback switch
  ///
  /// In en, this message translates to:
  /// **'Guests rate their meal. Feedback is collected once feedback storage exists; until then guests are not asked.'**
  String get studioFeatFeedbackHint;

  /// Studio > Guest features: switch title (show a dish's ingredients)
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get studioFeatIngredientsTitle;

  /// Studio > Guest features: explanation under the Ingredients switch
  ///
  /// In en, this message translates to:
  /// **'Shows the ingredients you add to a dish in the Menu tab.'**
  String get studioFeatIngredientsHint;

  /// Studio > Guest features: switch title (show a dish's allergens)
  ///
  /// In en, this message translates to:
  /// **'Allergens'**
  String get studioFeatAllergensTitle;

  /// Studio > Guest features: explanation under the Allergens switch
  ///
  /// In en, this message translates to:
  /// **'Shows the allergens you mark on each dish.'**
  String get studioFeatAllergensHint;

  /// Studio > Guest features: switch title (show a dish's calories)
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get studioFeatCaloriesTitle;

  /// Studio > Guest features: explanation under the Calories switch
  ///
  /// In en, this message translates to:
  /// **'Shows the kcal you enter for a dish.'**
  String get studioFeatCaloriesHint;

  /// Studio > Chef's picks: title of the bottom sheet that lists dishes to choose from
  ///
  /// In en, this message translates to:
  /// **'Add a chef\'s pick'**
  String get studioHighPickTitle;

  /// Studio > Limited today: title of the bottom sheet that lists dishes to choose from
  ///
  /// In en, this message translates to:
  /// **'Add a limited offer'**
  String get studioHighOfferTitle;

  /// Studio > Limited today: heading of the time picker where the owner chooses when the offer ends each day
  ///
  /// In en, this message translates to:
  /// **'Offer ends at'**
  String get studioHighEndsHelp;

  /// Studio > Chef's picks & offers: empty state title when the menu has no dishes
  ///
  /// In en, this message translates to:
  /// **'Add dishes first'**
  String get studioHighEmptyTitle;

  /// Studio > Chef's picks & offers: empty state text when the menu has no dishes
  ///
  /// In en, this message translates to:
  /// **'Chef\'s picks and offers come from your menu. Add dishes in the Menu tab.'**
  String get studioHighEmptyMessage;

  /// Studio > Chef's picks & offers: button on the empty state that goes to the Menu tab
  ///
  /// In en, this message translates to:
  /// **'Open Menu'**
  String get studioHighEmptyAction;

  /// Studio > Chef's picks: counter beside the heading, e.g. 2 of 6 picks chosen
  ///
  /// In en, this message translates to:
  /// **'{count} of {max}'**
  String studioHighPicksCount({required int count, required int max});

  /// Studio > Chef's picks: warning banner when the Chef's picks feature is off
  ///
  /// In en, this message translates to:
  /// **'Chef\'s picks are switched off, so guests do not see them.'**
  String get studioHighChefsOff;

  /// Studio > Limited today: warning banner when the Limited today feature is off
  ///
  /// In en, this message translates to:
  /// **'Limited today is switched off, so guests do not see offers.'**
  String get studioHighLimitedOff;

  /// Studio: button on a warning banner that switches the feature on
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get studioHighTurnOn;

  /// Studio > Chef's picks: title of the empty list
  ///
  /// In en, this message translates to:
  /// **'No picks yet'**
  String get studioHighNoPicks;

  /// Studio > Chef's picks: text of the empty list
  ///
  /// In en, this message translates to:
  /// **'Pick up to six dishes you are proud of. They show first.'**
  String get studioHighNoPicksHint;

  /// Studio: screen-reader label of the drag handle on a reorderable row (chef's picks, ways to order)
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get studioHighDragToReorder;

  /// Studio > Chef's picks and Limited today: row that opens the dish chooser
  ///
  /// In en, this message translates to:
  /// **'Add a dish'**
  String get studioHighAddDish;

  /// Studio > Limited today: title of the empty list
  ///
  /// In en, this message translates to:
  /// **'No offers yet'**
  String get studioHighNoOffers;

  /// Studio > Limited today: text of the empty list
  ///
  /// In en, this message translates to:
  /// **'Guests see a countdown until the time you set.'**
  String get studioHighNoOffersHint;

  /// Studio > Limited today: chip on an offer showing when it ends; {time} is a clock time such as 9:30 PM
  ///
  /// In en, this message translates to:
  /// **'Until {time}'**
  String studioHighUntil({required String time});

  /// Studio > Limited today: note under the list of offers
  ///
  /// In en, this message translates to:
  /// **'Offers repeat every day until you remove them. After the end time guests no longer see them that day.'**
  String get studioHighRepeatNote;

  /// Studio > Chef's picks / Limited today: name shown for a picked dish that was deleted from the menu
  ///
  /// In en, this message translates to:
  /// **'No longer on the menu'**
  String get studioHighGone;

  /// Studio > Chef's picks / Limited today: line under a picked dish that was deleted from the menu
  ///
  /// In en, this message translates to:
  /// **'Guests do not see it. Remove it.'**
  String get studioHighGoneHint;

  /// Studio > Chef's picks / Limited today: line under a picked dish that is marked sold out
  ///
  /// In en, this message translates to:
  /// **'Sold out, so guests do not see it'**
  String get studioHighSoldOutHint;

  /// Studio: placeholder of the search box in the dish chooser sheet
  ///
  /// In en, this message translates to:
  /// **'Search dishes'**
  String get studioHighSearchHint;

  /// Studio: empty state of the dish chooser when nothing matches the search
  ///
  /// In en, this message translates to:
  /// **'No dishes to pick'**
  String get studioHighNoDishes;

  /// Studio: line under a sold-out dish in the dish chooser; {price} is a rupee amount
  ///
  /// In en, this message translates to:
  /// **'{price} · sold out'**
  String studioHighPriceSoldOut({required String price});

  /// Studio > How guests order: heading above the list of ways (dine-in, takeaway, pre-order, delivery)
  ///
  /// In en, this message translates to:
  /// **'Ways to order'**
  String get studioSvcWaysTitle;

  /// Studio > How guests order: explanation above the list of ways
  ///
  /// In en, this message translates to:
  /// **'Guests choose one when they start. Drag to change the order they see.'**
  String get studioSvcWaysHint;

  /// Studio > How guests order: message shown when the owner tries to switch off the last remaining way
  ///
  /// In en, this message translates to:
  /// **'Keep at least one way to order switched on.'**
  String get studioSvcKeepOne;

  /// Studio > How guests order: heading of the card where the owner chooses the word guests see before the table number (Table 12, Room 12)
  ///
  /// In en, this message translates to:
  /// **'What you call a table'**
  String get studioSvcTableTitle;

  /// Studio > How guests order: chip to type a different word than Table or Room
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get studioSvcTableOther;

  /// Studio > How guests order: field label for the word that replaces Table
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get studioSvcTableField;

  /// Studio > How guests order: examples inside the label field
  ///
  /// In en, this message translates to:
  /// **'Cabin, Tent, Lounge…'**
  String get studioSvcTableExamples;

  /// Studio > How guests order: sample line; {label} is the word the owner chose, shown with a table number 12
  ///
  /// In en, this message translates to:
  /// **'Guests see \"{label} 12\" on their order.'**
  String studioSvcTableSample({required String label});

  /// Studio > How guests order: text of the Pre-order card while Pre-order is switched off
  ///
  /// In en, this message translates to:
  /// **'Switch on Pre-order above to let guests schedule a pickup, and set the days and times here.'**
  String get studioSvcPreOff;

  /// Studio > Pre-order: heading of the row that sets how many days ahead a guest may book
  ///
  /// In en, this message translates to:
  /// **'Book ahead'**
  String get studioSvcBookAhead;

  /// Studio > Pre-order: how many days ahead guests may book
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Up to 1 day, today included} other{Up to {count} days, today included}}'**
  String studioSvcBookDays({required int count});

  /// Studio > Pre-order: tooltip of the minus button
  ///
  /// In en, this message translates to:
  /// **'Fewer days'**
  String get studioSvcFewerDays;

  /// Studio > Pre-order: tooltip of the plus button
  ///
  /// In en, this message translates to:
  /// **'More days'**
  String get studioSvcMoreDays;

  /// Studio > Pre-order: label of the box showing the first pickup time of the day
  ///
  /// In en, this message translates to:
  /// **'Opens at'**
  String get studioSvcOpensAt;

  /// Studio > Pre-order: label of the box showing when pickups stop for the day
  ///
  /// In en, this message translates to:
  /// **'Closes at'**
  String get studioSvcClosesAt;

  /// Studio > Pre-order: red error when closing time is too close to opening time
  ///
  /// In en, this message translates to:
  /// **'Closing time must be at least one slot after opening time.'**
  String get studioSvcBadHours;

  /// Studio > Pre-order: heading above the choices 15 min, 30 min, 1 h ... (the gap between two pickup times)
  ///
  /// In en, this message translates to:
  /// **'Pickup slots every'**
  String get studioSvcSlotEvery;

  /// Studio > Pre-order: heading above the choices for how far ahead of pickup a guest must order
  ///
  /// In en, this message translates to:
  /// **'Minimum notice'**
  String get studioSvcLead;

  /// Studio > Pre-order: a duration under one hour on a choice chip
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String studioSvcMinutes({required int minutes});

  /// Studio > Pre-order: a whole number of hours on a choice chip
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String studioSvcHours({required int hours});

  /// Studio > Pre-order: hours and minutes on a choice chip
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String studioSvcHoursMinutes({required int hours, required int minutes});

  /// Studio > Pre-order: heading above the preview of pickup times guests will see
  ///
  /// In en, this message translates to:
  /// **'What guests can pick'**
  String get studioSvcGuestPick;

  /// Studio > Pre-order: day name above tomorrow's pickup times (the next day, not the day before)
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get studioSvcTomorrow;

  /// Studio > Pre-order: shown instead of pickup times when a day has none
  ///
  /// In en, this message translates to:
  /// **'No pickup times'**
  String get studioSvcNoSlots;

  /// One line under the Dine-in way to order, as the guest sees it
  ///
  /// In en, this message translates to:
  /// **'Order fresh at your table'**
  String get studioSvcModeDineInHint;

  /// One line under the Takeaway way to order, as the guest sees it
  ///
  /// In en, this message translates to:
  /// **'Pick up at the counter'**
  String get studioSvcModeTakeawayHint;

  /// One line under the Pre-order way to order, as the guest sees it
  ///
  /// In en, this message translates to:
  /// **'Schedule a pickup for later'**
  String get studioSvcModePreOrderHint;

  /// One line under the Delivery way to order, as the guest sees it
  ///
  /// In en, this message translates to:
  /// **'Delivered to your door'**
  String get studioSvcModeDeliveryHint;

  /// App bar title of the Team screen
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get teamTitle;

  /// Team screen, shown to a role that may not look at the team: title
  ///
  /// In en, this message translates to:
  /// **'Not available for your role'**
  String get teamNotAvailableTitle;

  /// Team screen, shown to a role that may not look at the team: line under the title
  ///
  /// In en, this message translates to:
  /// **'Ask an owner or admin about your team.'**
  String get teamNotAvailableMessage;

  /// Team screen: progress label while the list loads
  ///
  /// In en, this message translates to:
  /// **'Loading the team…'**
  String get teamLoading;

  /// Team screen: notice banner shown to everyone who is not an organization admin
  ///
  /// In en, this message translates to:
  /// **'Only an organization admin can change roles or suspend people.'**
  String get teamReadOnlyNotice;

  /// Team screen: title when the restaurant has no team members
  ///
  /// In en, this message translates to:
  /// **'No one is listed yet'**
  String get teamEmptyTitle;

  /// Team screen: line under the empty-team title
  ///
  /// In en, this message translates to:
  /// **'People you invite from the VINII control panel show up here once they accept.'**
  String get teamEmptyMessage;

  /// Team screen: hint inside the search field (shown once the team is long)
  ///
  /// In en, this message translates to:
  /// **'Search by name, email or role'**
  String get teamSearchHint;

  /// Team screen: title when the search or role filter finds no one
  ///
  /// In en, this message translates to:
  /// **'Nobody matches'**
  String get teamNoMatchTitle;

  /// Team screen: line under the no-match title
  ///
  /// In en, this message translates to:
  /// **'Try another name, or show everyone.'**
  String get teamNoMatchMessage;

  /// Team screen: button that clears the search and the role filter
  ///
  /// In en, this message translates to:
  /// **'Show everyone'**
  String get teamShowEveryone;

  /// Team screen: headline count when the team is empty
  ///
  /// In en, this message translates to:
  /// **'No one yet'**
  String get teamSummaryNone;

  /// Team screen: headline count when everyone is active
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person} other{{count} people}}'**
  String teamSummaryPeople({required int count});

  /// Team screen: headline count when some people are suspended; {active} is how many are active
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person} other{{count} people}} · {active} active'**
  String teamSummaryPeopleActive({required int count, required int active});

  /// Team screen: button (admins only) and the title of the sheet it opens
  ///
  /// In en, this message translates to:
  /// **'Invite staff'**
  String get teamInviteStaff;

  /// Team screen: role filter chip that shows the whole team; {count} is the team size
  ///
  /// In en, this message translates to:
  /// **'Everyone ({count})'**
  String teamFilterEveryone({required int count});

  /// Team screen: role filter chip; {role} is the role name, {count} how many people have it
  ///
  /// In en, this message translates to:
  /// **'{role} ({count})'**
  String teamFilterRole({required String role, required int count});

  /// Team screen: heading of the card that lists every role in use with what it can do
  ///
  /// In en, this message translates to:
  /// **'What each role can do'**
  String get teamLegendTitle;

  /// Team screen: small badge next to the signed-in person in the list
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get teamYou;

  /// Person sheet: action that opens the role picker
  ///
  /// In en, this message translates to:
  /// **'Change role'**
  String get teamChangeRole;

  /// Person sheet: line under Change role naming the role they have now
  ///
  /// In en, this message translates to:
  /// **'Now {role}'**
  String teamCurrentRole({required String role});

  /// Person sheet action and the confirm button of the suspend dialog: stop this person using the restaurant
  ///
  /// In en, this message translates to:
  /// **'Suspend'**
  String get teamSuspend;

  /// Person sheet: line under the Suspend action
  ///
  /// In en, this message translates to:
  /// **'They cannot use this restaurant until you reactivate them.'**
  String get teamSuspendHint;

  /// Person sheet action and the confirm button of the reactivate dialog: let a suspended person use the restaurant again
  ///
  /// In en, this message translates to:
  /// **'Reactivate'**
  String get teamReactivate;

  /// Person sheet: line under the Reactivate action
  ///
  /// In en, this message translates to:
  /// **'Let them use this restaurant again.'**
  String get teamReactivateHint;

  /// Suspend dialog: title; {name} is the person
  ///
  /// In en, this message translates to:
  /// **'Suspend {name}?'**
  String teamSuspendTitle({required String name});

  /// Suspend dialog: what suspending means; {name} is the person
  ///
  /// In en, this message translates to:
  /// **'{name} will not be able to use this restaurant until you reactivate them. Nothing is deleted.'**
  String teamSuspendBody({required String name});

  /// Reactivate dialog: title; {name} is the person
  ///
  /// In en, this message translates to:
  /// **'Reactivate {name}?'**
  String teamReactivateTitle({required String name});

  /// Reactivate dialog: what reactivating means; {name} is the person, {role} the role they keep
  ///
  /// In en, this message translates to:
  /// **'{name} will be able to use this restaurant again, as {role}.'**
  String teamReactivateBody({required String name, required String role});

  /// Snackbar after suspending someone; {name} is the person
  ///
  /// In en, this message translates to:
  /// **'{name} is suspended.'**
  String teamSuspendedDone({required String name});

  /// Snackbar after reactivating someone; {name} is the person
  ///
  /// In en, this message translates to:
  /// **'{name} is active again.'**
  String teamReactivatedDone({required String name});

  /// Snackbar after changing someone's role; {name} is the person, {role} the new role
  ///
  /// In en, this message translates to:
  /// **'{name} is now {role}.'**
  String teamRoleChangedDone({required String name, required String role});

  /// Role picker sheet: title; {name} is the person
  ///
  /// In en, this message translates to:
  /// **'Change role for {name}'**
  String teamPickRoleTitle({required String name});

  /// Role picker: the role the person has at the moment; {role} is the role name
  ///
  /// In en, this message translates to:
  /// **'{role} (now)'**
  String teamRoleNow({required String role});

  /// Role picker: confirm button once another role is chosen; {role} is the chosen role
  ///
  /// In en, this message translates to:
  /// **'Make {role}'**
  String teamMakeRole({required String role});

  /// Role picker: disabled confirm button until another role is chosen
  ///
  /// In en, this message translates to:
  /// **'Choose a different role'**
  String get teamChooseDifferent;

  /// Invite staff sheet: why invitations are not sent from the phone; Users & Roles is a menu name in the web control panel
  ///
  /// In en, this message translates to:
  /// **'Invitations are sent from the VINII control panel, under Users & Roles, because each person needs a secure link to set up their own login.'**
  String get teamInviteIntro;

  /// Invite staff sheet: what happens after the invitation is accepted
  ///
  /// In en, this message translates to:
  /// **'Once they accept, they appear here and you can set their role.'**
  String get teamInviteAfter;

  /// Invite staff sheet: button that closes it
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get teamGotIt;

  /// Why a team change is not allowed (failure code team_not_admin); shown under Change role / Suspend and as an error
  ///
  /// In en, this message translates to:
  /// **'Only an organization admin can change the team.'**
  String get teamBlockNotAdmin;

  /// Why a team change is not allowed (failure code team_self_role)
  ///
  /// In en, this message translates to:
  /// **'You cannot change your own role.'**
  String get teamBlockSelfRole;

  /// Why a team change is not allowed (failure code team_self_suspend)
  ///
  /// In en, this message translates to:
  /// **'You cannot suspend yourself.'**
  String get teamBlockSelfSuspend;

  /// Why a team change is not allowed (failure code team_last_admin): the last active admin cannot be demoted or suspended
  ///
  /// In en, this message translates to:
  /// **'There must always be one active admin. Make someone else an admin first.'**
  String get teamBlockLastAdmin;

  /// Error when a person is changed twice at once (failure code team_already_saving)
  ///
  /// In en, this message translates to:
  /// **'Already saving…'**
  String get teamAlreadySaving;

  /// A thing a role can do, as it appears in a list of abilities: change roles and suspend people
  ///
  /// In en, this message translates to:
  /// **'manage the team'**
  String get teamAbilityManageTeam;

  /// A thing a role can do, in a list of abilities
  ///
  /// In en, this message translates to:
  /// **'change the bill and GST settings'**
  String get teamAbilityChangeBillSettings;

  /// A thing a role can do, in a list of abilities
  ///
  /// In en, this message translates to:
  /// **'publish the guest storefront'**
  String get teamAbilityPublishStorefront;

  /// A thing a role can do, in a list of abilities
  ///
  /// In en, this message translates to:
  /// **'edit the guest storefront'**
  String get teamAbilityEditStorefront;

  /// A thing a role can do, in a list of abilities
  ///
  /// In en, this message translates to:
  /// **'edit the menu'**
  String get teamAbilityEditMenu;

  /// A thing a role can do, in a list of abilities: mark a dish available or sold out
  ///
  /// In en, this message translates to:
  /// **'switch dishes on and off'**
  String get teamAbilitySwitchDishes;

  /// A thing a role can do, in a list of abilities: open or close the store for delivery orders
  ///
  /// In en, this message translates to:
  /// **'change the store status'**
  String get teamAbilityChangeStoreStatus;

  /// A thing a role can do, in a list of abilities
  ///
  /// In en, this message translates to:
  /// **'remove the service charge from a bill'**
  String get teamAbilityWaiveServiceCharge;

  /// A thing a role can do, in a list of abilities
  ///
  /// In en, this message translates to:
  /// **'take payments'**
  String get teamAbilityTakePayments;

  /// A thing a role can do, in a list of abilities
  ///
  /// In en, this message translates to:
  /// **'take table orders'**
  String get teamAbilityTakeTableOrders;

  /// A thing a role can do, in a list of abilities
  ///
  /// In en, this message translates to:
  /// **'accept delivery orders'**
  String get teamAbilityAcceptDeliveryOrders;

  /// A thing a role can do, in a list of abilities: tell the guest or rider the food is ready
  ///
  /// In en, this message translates to:
  /// **'mark food ready'**
  String get teamAbilityMarkFoodReady;

  /// A thing a role can do, in a list of abilities
  ///
  /// In en, this message translates to:
  /// **'see delivery orders'**
  String get teamAbilitySeeDeliveryOrders;

  /// A thing a role can do, in a list of abilities
  ///
  /// In en, this message translates to:
  /// **'see the menu'**
  String get teamAbilitySeeMenu;

  /// A thing a role can do, in a list of abilities
  ///
  /// In en, this message translates to:
  /// **'see the bill settings'**
  String get teamAbilitySeeBillSettings;

  /// What a role can do when it has one ability. Hindi drops the word for Can: the list sits under a heading or beside a role name that already says what it can do. {first} is one ability phrase
  ///
  /// In en, this message translates to:
  /// **'Can {first}.'**
  String teamSummaryOne({required String first});

  /// What a role can do with two abilities; each placeholder is one ability phrase
  ///
  /// In en, this message translates to:
  /// **'Can {first} and {second}.'**
  String teamSummaryTwo({required String first, required String second});

  /// What a role can do with three abilities; each placeholder is one ability phrase
  ///
  /// In en, this message translates to:
  /// **'Can {first}, {second} and {third}.'**
  String teamSummaryThree({
    required String first,
    required String second,
    required String third,
  });

  /// What a role can do with more than three abilities: the first three, then and more
  ///
  /// In en, this message translates to:
  /// **'Can {first}, {second}, {third} and more.'**
  String teamSummaryMore({
    required String first,
    required String second,
    required String third,
  });

  /// What a role can do when it has nothing in this app; Orders, Sell and Menu are the names of the bottom tabs
  ///
  /// In en, this message translates to:
  /// **'Cannot use Orders, Sell or Menu in this app.'**
  String get teamSummaryNothing;

  /// Staff screen when a role without the hand-to-guest ability opens the guest page
  ///
  /// In en, this message translates to:
  /// **'Your role cannot hand this phone to guests.'**
  String get guestHostNotAllowedMessage;

  /// Staff loading screen while the menu and published storefront load before the phone is handed over
  ///
  /// In en, this message translates to:
  /// **'Getting the menu ready…'**
  String get guestHostLoading;

  /// Staff screen title when there is no published storefront to show guests
  ///
  /// In en, this message translates to:
  /// **'Publish your storefront in Studio first'**
  String get guestHostPublishTitle;

  /// Staff screen explanation under the publish-first title
  ///
  /// In en, this message translates to:
  /// **'Guests see the published storefront. Open Storefront, check the preview and publish it, then hand the phone over.'**
  String get guestHostPublishBody;

  /// Guest page heading when no dish on the menu can be sold yet (restaurant may override this text in its storefront copy)
  ///
  /// In en, this message translates to:
  /// **'The menu is being prepared'**
  String get guestMenuPreparingTitle;

  /// Guest page text under the menu-is-being-prepared heading
  ///
  /// In en, this message translates to:
  /// **'Please check back in a little while, or ask a member of our staff.'**
  String get guestMenuPreparingBody;

  /// The word for a table, shown in Table 12 lines when the restaurant has not chosen its own word
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get guestTableWord;

  /// Main button on the guest welcome screen (restaurant may override in its storefront copy)
  ///
  /// In en, this message translates to:
  /// **'Start exploring'**
  String get guestWelcomeStart;

  /// Title of the main service pill on the guest welcome screen when dine-in is offered
  ///
  /// In en, this message translates to:
  /// **'Order now'**
  String get guestWelcomeOrderNow;

  /// Second part of the Order now pill on the welcome screen, with the table such as Table 12
  ///
  /// In en, this message translates to:
  /// **'Dine-in at {table}'**
  String guestWelcomeDineInAt({required String table});

  /// Second part of the Pre-order pill on the welcome screen
  ///
  /// In en, this message translates to:
  /// **'Schedule for later'**
  String get guestWelcomePreOrderHint;

  /// Name of the pre-order service mode on the guest welcome screen and the mode choice screen
  ///
  /// In en, this message translates to:
  /// **'Pre-order'**
  String get guestModePreOrder;

  /// Heading of the guest screen where the guest picks dine-in, takeaway, pre-order or delivery; name is the restaurant
  ///
  /// In en, this message translates to:
  /// **'How would you like to enjoy {name}?'**
  String guestModeTitle({required String name});

  /// Subtitle of the dine-in card when the table is not known
  ///
  /// In en, this message translates to:
  /// **'Order fresh at your table'**
  String get guestModeDineInHint;

  /// Subtitle of the dine-in card when the guest scanned a table, such as Table 12
  ///
  /// In en, this message translates to:
  /// **'Order fresh at {table}'**
  String guestModeDineInAt({required String table});

  /// Subtitle of the takeaway card on the guest mode screen and welcome pill
  ///
  /// In en, this message translates to:
  /// **'Pick up at the counter'**
  String get guestModeTakeawayHint;

  /// Subtitle of the pre-order card on the guest mode screen
  ///
  /// In en, this message translates to:
  /// **'Schedule a pickup for later'**
  String get guestModePreOrderHint;

  /// Subtitle of the delivery card on the guest mode screen and welcome pill
  ///
  /// In en, this message translates to:
  /// **'Delivered to your door'**
  String get guestModeDeliveryHint;

  /// Title of the guest specials screen and tooltip of the sparkle button that opens it
  ///
  /// In en, this message translates to:
  /// **'Specials'**
  String get guestSpecials;

  /// Title of the guest discover screen opened from live tracking while the order is prepared
  ///
  /// In en, this message translates to:
  /// **'Discover more'**
  String get guestDiscoverMore;

  /// Line under the Discover more title
  ///
  /// In en, this message translates to:
  /// **'Keep exploring while we prepare your order.'**
  String get guestDiscoverWaiting;

  /// Section heading of the chef's picks row on the guest specials screen
  ///
  /// In en, this message translates to:
  /// **'Chef\'s picks'**
  String get guestDiscoverChefsPicks;

  /// Small line after the chef's picks heading
  ///
  /// In en, this message translates to:
  /// **'Curated for you'**
  String get guestDiscoverCurated;

  /// Section heading of offers that end today on the guest specials screen
  ///
  /// In en, this message translates to:
  /// **'Limited today'**
  String get guestDiscoverLimited;

  /// Countdown chip beside Limited today, time is hours:minutes:seconds
  ///
  /// In en, this message translates to:
  /// **'Ends in {time}'**
  String guestDiscoverEndsIn({required String time});

  /// Section heading of bestsellers on the guest specials screen
  ///
  /// In en, this message translates to:
  /// **'Recommended for you'**
  String get guestDiscoverRecommended;

  /// Section heading shown when a restaurant has no picks, offers or bestsellers
  ///
  /// In en, this message translates to:
  /// **'From the menu'**
  String get guestDiscoverFromMenu;

  /// Tooltip of the heart button on a dish card when the dish is not saved
  ///
  /// In en, this message translates to:
  /// **'Save for later'**
  String get guestDishSave;

  /// Tooltip of the heart button on a dish card when the dish is saved
  ///
  /// In en, this message translates to:
  /// **'Saved for later'**
  String get guestDishSaved;

  /// Tooltip of the plus button on a dish card; name is the dish
  ///
  /// In en, this message translates to:
  /// **'Add {name}'**
  String guestDishAddTooltip({required String name});

  /// Heading of the guest categories screen (restaurant may override in its storefront copy)
  ///
  /// In en, this message translates to:
  /// **'What are you in the mood for?'**
  String get guestCategoriesTitle;

  /// Heading of the guest categories carousel
  ///
  /// In en, this message translates to:
  /// **'Swipe to explore categories'**
  String get guestCategoriesSwipeHint;

  /// Name of the category that holds every dish
  ///
  /// In en, this message translates to:
  /// **'All dishes'**
  String get guestAllDishes;

  /// How many dishes a category tile holds
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 dish} other{{count} dishes}}'**
  String guestDishCount({required int count});

  /// Button under the categories carousel when All dishes is in the middle
  ///
  /// In en, this message translates to:
  /// **'Explore all dishes'**
  String get guestExploreAll;

  /// Button under the categories carousel; name is the category
  ///
  /// In en, this message translates to:
  /// **'Explore {name}'**
  String guestExploreCategory({required String name});

  /// Words on the floating cart bar (restaurant may override in its storefront copy)
  ///
  /// In en, this message translates to:
  /// **'View order'**
  String get guestCartView;

  /// Floating cart bar text: the View order words followed by how many portions are in the order
  ///
  /// In en, this message translates to:
  /// **'{label} ({count})'**
  String guestCartBarLabel({required String label, required int count});

  /// Hint in the guest dish search box (restaurant may override in its storefront copy)
  ///
  /// In en, this message translates to:
  /// **'Search dishes'**
  String get guestSearchHint;

  /// Guest dish search when nothing matches what was typed
  ///
  /// In en, this message translates to:
  /// **'Nothing matches \"{query}\".'**
  String guestSearchNoMatch({required String query});

  /// Under the budget amount on the browse screen
  ///
  /// In en, this message translates to:
  /// **'{percent}% used'**
  String guestBudgetUsed({required int percent});

  /// Browse screen when the chosen diet filter leaves no dish; diet is veg, nonVeg or jain
  ///
  /// In en, this message translates to:
  /// **'{diet, select, veg{Nothing veg here} nonVeg{Nothing non-veg here} jain{Nothing jain here} other{Nothing here}}'**
  String guestNothingForDiet({required String diet});

  /// Button that clears the veg, non-veg or Jain filter
  ///
  /// In en, this message translates to:
  /// **'Show everything'**
  String get guestShowEverything;

  /// Label of the icon that switches browsing to swipe cards
  ///
  /// In en, this message translates to:
  /// **'Swipe dishes'**
  String get guestViewSwipe;

  /// Label of the icon that switches browsing to the traditional menu list
  ///
  /// In en, this message translates to:
  /// **'Menu view'**
  String get guestViewMenu;

  /// Under the dish pictures of an order when more dishes than the pictures shown
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String guestTrayMore({required int count});

  /// Why Place order cannot be pressed: the cart is empty
  ///
  /// In en, this message translates to:
  /// **'Add something to your order first.'**
  String get guestBlockerEmpty;

  /// Why Place order cannot be pressed: dine-in without a table from a QR code; table is the restaurant's word for a table in lower case
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code on your {table} to order from it.'**
  String guestBlockerScanTable({required String table});

  /// Why Place order cannot be pressed: pre-order without a time
  ///
  /// In en, this message translates to:
  /// **'Choose a pickup time first.'**
  String get guestBlockerPickupTime;

  /// Why Place order cannot be pressed: delivery details missing
  ///
  /// In en, this message translates to:
  /// **'Add your name, phone and address for delivery.'**
  String get guestBlockerDeliveryDetails;

  /// Under the coupon field when the guest taps Apply with nothing typed
  ///
  /// In en, this message translates to:
  /// **'Enter a coupon code.'**
  String get guestCouponEnterCode;

  /// Under the coupon field when the server rejects a code without giving a reason
  ///
  /// In en, this message translates to:
  /// **'That code doesn\'t apply.'**
  String get guestCouponNotApplicable;

  /// Under the coupon row when the order changed and the applied coupon no longer fits; reason says why
  ///
  /// In en, this message translates to:
  /// **'Coupon {code} was taken off: {reason}'**
  String guestCouponTakenOff({required String code, required String reason});

  /// Failure code guest_already_placing: Place order tapped while the order is already being sent
  ///
  /// In en, this message translates to:
  /// **'Already placing your order.'**
  String get failGuestAlreadyPlacing;

  /// Failure code guest_not_marked_guest: a guest order was sent without the placed-by-guest mark (a bug, not shown in normal use)
  ///
  /// In en, this message translates to:
  /// **'Guest orders must be marked as placed by the guest.'**
  String get failGuestNotMarkedGuest;

  /// Tooltip of the faint lock in the guest top bar; staff only, a long-press hands the phone back
  ///
  /// In en, this message translates to:
  /// **'Staff: press and hold to leave'**
  String get guestWidgetExitTooltip;

  /// Title of the confirm dialog that hands the phone back from the guest menu to staff
  ///
  /// In en, this message translates to:
  /// **'Return to staff mode?'**
  String get guestWidgetExitTitle;

  /// Body of the return-to-staff confirm dialog
  ///
  /// In en, this message translates to:
  /// **'The guest menu will close on this phone.'**
  String get guestWidgetExitBody;

  /// Button in the return-to-staff dialog: keep the guest menu open
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get guestWidgetExitStay;

  /// Button in the return-to-staff dialog: leave the guest menu
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get guestWidgetExitReturn;

  /// Small pill on a dish's detail page, added automatically for a veg dish
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get guestWidgetTagVegetarian;

  /// Tooltip of the minus button on a quantity stepper
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get guestWidgetQtyLess;

  /// Tooltip of the plus button on a quantity stepper
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get guestWidgetQtyMore;

  /// Banner on guest screens after ordering, shown only inside the Studio preview
  ///
  /// In en, this message translates to:
  /// **'Preview — nothing was sent to the kitchen'**
  String get guestWidgetPreview;

  /// Heading of the budget note when the table has spent more than its budget
  ///
  /// In en, this message translates to:
  /// **'You\'re over your budget'**
  String get guestBudgetOverTitle;

  /// Heading of the budget note when the table is above 85% of its budget
  ///
  /// In en, this message translates to:
  /// **'Getting close to your budget'**
  String get guestBudgetCloseTitle;

  /// Heading of the budget note while the table is comfortably within its budget
  ///
  /// In en, this message translates to:
  /// **'You\'re well within your budget!'**
  String get guestBudgetWithinTitle;

  /// Second line of the budget note when over budget; amount is rupees
  ///
  /// In en, this message translates to:
  /// **'{amount} over'**
  String guestBudgetOverBy({required String amount});

  /// Second line of the budget note: what is left of the budget; amount is rupees
  ///
  /// In en, this message translates to:
  /// **'{amount} remaining'**
  String guestBudgetRemaining({required String amount});

  /// Label above the budget amount on the table budget screen, and title of the dialog where the guest types an amount
  ///
  /// In en, this message translates to:
  /// **'Total budget'**
  String get guestBudgetTotal;

  /// Button of the dialog where the guest types a budget amount
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get guestBudgetSet;

  /// Tooltip of the pencil button next to the budget amount
  ///
  /// In en, this message translates to:
  /// **'Type an amount'**
  String get guestBudgetTypeAmount;

  /// Label above the people stepper on the table budget screen
  ///
  /// In en, this message translates to:
  /// **'Split between'**
  String get guestBudgetSplitBetween;

  /// Under the people stepper on the table budget screen: how many people and each one's share of the budget; amount is rupees
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person} other{{count} people}}  ·  {amount} per person'**
  String guestBudgetPerPerson({required int count, required String amount});

  /// Main button of the table budget screen (restaurant may override in its storefront copy)
  ///
  /// In en, this message translates to:
  /// **'Save & continue'**
  String get guestBudgetSaveContinue;

  /// Heading of the table budget screen (restaurant may override in its storefront copy)
  ///
  /// In en, this message translates to:
  /// **'Dining with friends?'**
  String get guestBudgetTitle;

  /// Line under the heading of the table budget screen (restaurant may override in its storefront copy)
  ///
  /// In en, this message translates to:
  /// **'Set a budget to stay on track.'**
  String get guestBudgetSubtitle;

  /// Main button of the budget overview screen
  ///
  /// In en, this message translates to:
  /// **'View full order'**
  String get guestBudgetViewOrder;

  /// Title of the budget overview screen opened by tapping the budget ring
  ///
  /// In en, this message translates to:
  /// **'Your budget'**
  String get guestBudgetOverviewTitle;

  /// Small caption under the spent amount on the budget overview: the figure is an estimate
  ///
  /// In en, this message translates to:
  /// **'Estimated'**
  String get guestBudgetEstimated;

  /// Section title on the budget overview listing the last dishes added
  ///
  /// In en, this message translates to:
  /// **'Recent additions'**
  String get guestBudgetRecent;

  /// Brief green toast over the swipe deck after a dish is added; name is the dish name
  ///
  /// In en, this message translates to:
  /// **'Added · {name}'**
  String guestDeckAdded({required String name});

  /// Hint under the swipe deck (restaurant may override in its storefront copy)
  ///
  /// In en, this message translates to:
  /// **'Swipe right to add'**
  String get guestDeckSwipeHint;

  /// Tooltip of the green add button under the swipe deck and the screen-reader action on a dish card
  ///
  /// In en, this message translates to:
  /// **'Add to order'**
  String get guestDeckAddToOrder;

  /// Tooltip of the up button under the swipe deck, the small handle on a dish card and a keyboard hint
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get guestDeckDetails;

  /// Screen-reader action on a dish card: skip the dish
  ///
  /// In en, this message translates to:
  /// **'Skip this dish'**
  String get guestDeckSkipDish;

  /// Screen-reader hint on the front dish card
  ///
  /// In en, this message translates to:
  /// **'Double tap for details'**
  String get guestDeckDetailsHint;

  /// Part of the screen-reader name of a dish card that is already in the order; qty is how many
  ///
  /// In en, this message translates to:
  /// **'in your order, {qty}'**
  String guestDeckInOrderLabel({required int qty});

  /// Green badge on a dish card that is already in the order; qty is how many
  ///
  /// In en, this message translates to:
  /// **'In order ×{qty}'**
  String guestDeckInOrder({required int qty});

  /// Green stamp that appears on a dish card while it is dragged right (short, large type)
  ///
  /// In en, this message translates to:
  /// **'ADD'**
  String get guestDeckStampAdd;

  /// Red stamp that appears on a dish card while it is dragged left (short, large type)
  ///
  /// In en, this message translates to:
  /// **'SKIP'**
  String get guestDeckStampSkip;

  /// Heading when the swipe deck of a category runs out; category is the category name
  ///
  /// In en, this message translates to:
  /// **'You\'ve seen every dish in {category}'**
  String guestDeckSeenAll({required String category});

  /// Line under the end-of-deck heading when the order is still empty
  ///
  /// In en, this message translates to:
  /// **'Go round again, or try another category.'**
  String get guestDeckGoRound;

  /// Line under the end-of-deck heading when the order has dishes; count is the number of portions
  ///
  /// In en, this message translates to:
  /// **'{count} in your order so far.'**
  String guestDeckInOrderSoFar({required int count});

  /// Button at the end of the swipe deck: bring the skipped dishes back
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get guestDeckStartOver;

  /// Main button of the dish detail page with the running price; price is rupees
  ///
  /// In en, this message translates to:
  /// **'Add to order · {price}'**
  String guestItemAddToOrder({required String price});

  /// Section title on the dish detail page
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get guestItemIngredients;

  /// Collapsible row on the dish detail page
  ///
  /// In en, this message translates to:
  /// **'Allergen information'**
  String get guestItemAllergens;

  /// Inside the allergen row; list is the allergens joined by commas
  ///
  /// In en, this message translates to:
  /// **'Contains: {list}'**
  String guestItemContains({required String list});

  /// Collapsible row on the dish detail page
  ///
  /// In en, this message translates to:
  /// **'Nutritional info'**
  String get guestItemNutrition;

  /// Inside the nutrition row; kcal is the number of calories
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal per serving'**
  String guestItemKcal({required int kcal});

  /// Small line at the bottom of the dish detail page
  ///
  /// In en, this message translates to:
  /// **'About {minutes} min to prepare'**
  String guestItemPrep({required int minutes});

  /// Heading of the sheet that rises after a dish is added from its detail page
  ///
  /// In en, this message translates to:
  /// **'Added to your order!'**
  String get guestItemAddedTitle;

  /// Button of the added-to-order sheet: close it and keep browsing
  ///
  /// In en, this message translates to:
  /// **'Keep exploring'**
  String get guestItemKeepExploring;

  /// Title of the order screen and of the wide order panel (restaurant may override in its storefront copy)
  ///
  /// In en, this message translates to:
  /// **'Your order'**
  String get guestOrderTitle;

  /// Main button of the order screen (restaurant may override in its storefront copy); the total follows it
  ///
  /// In en, this message translates to:
  /// **'Place order'**
  String get guestOrderPlace;

  /// Label of the place-order button: the button words, then the total; total is rupees
  ///
  /// In en, this message translates to:
  /// **'{label} · {total}'**
  String guestOrderPlaceTotal({required String label, required String total});

  /// Text button at the top of the order screen: empty the order
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get guestOrderClearAll;

  /// Note card on the order screen for a takeaway order
  ///
  /// In en, this message translates to:
  /// **'We\'ll call your order number at the counter.'**
  String get guestOrderTakeawayNote;

  /// Label above the note-for-the-kitchen field on the order screen
  ///
  /// In en, this message translates to:
  /// **'Special instructions (optional)'**
  String get guestOrderNotesLabel;

  /// Hint inside the note-for-the-kitchen field (restaurant may override in its storefront copy)
  ///
  /// In en, this message translates to:
  /// **'Any special requests? (less spicy, no onions…)'**
  String get guestOrderNotesHint;

  /// Name of the discount line on the estimated bill when a coupon is applied; code is the coupon code
  ///
  /// In en, this message translates to:
  /// **'Coupon {code}'**
  String guestOrderCouponLine({required String code});

  /// Small line above the budget bar on the order screen; amount is rupees
  ///
  /// In en, this message translates to:
  /// **'Table budget {amount}'**
  String guestOrderTableBudget({required String amount});

  /// Quiet line on the order screen inside the Studio preview when there is no table; table is the lower-case word for a table (table, room...)
  ///
  /// In en, this message translates to:
  /// **'In the live storefront, your {table} comes from the QR code on it.'**
  String guestOrderQrPreview({required String table});

  /// Quiet line on the order screen for dine-in when the table is unknown; table is the lower-case word for a table (table, room...)
  ///
  /// In en, this message translates to:
  /// **'Your {table} comes from the QR code on it. Scan it to order from your {table}.'**
  String guestOrderQrScan({required String table});

  /// Empty state heading on the order screen
  ///
  /// In en, this message translates to:
  /// **'Your order is empty'**
  String get guestOrderEmpty;

  /// Button of the empty order screen: go back to the menu
  ///
  /// In en, this message translates to:
  /// **'Browse dishes'**
  String get guestOrderBrowse;

  /// Section title on the order screen above the dishes the guest saved with the heart
  ///
  /// In en, this message translates to:
  /// **'Saved for later'**
  String get guestOrderSavedHeading;

  /// Small tappable line under a dish in the order: set the quantity to the party size; count is the number of people
  ///
  /// In en, this message translates to:
  /// **'For all {count}'**
  String guestOrderForAll({required int count});

  /// Heading of the coupon card once the server accepted a code; code is the coupon code
  ///
  /// In en, this message translates to:
  /// **'{code} applied'**
  String guestOrderCouponApplied({required String code});

  /// Second line of the applied coupon card; amount is rupees
  ///
  /// In en, this message translates to:
  /// **'You save {amount}'**
  String guestOrderCouponSave({required String amount});

  /// Quiet row on the order screen that opens the coupon field
  ///
  /// In en, this message translates to:
  /// **'Have a coupon code?'**
  String get guestOrderCouponHave;

  /// Hint inside the coupon code field
  ///
  /// In en, this message translates to:
  /// **'Coupon code'**
  String get guestOrderCouponHint;

  /// Card on the order screen for a pre-order before a pickup slot is chosen
  ///
  /// In en, this message translates to:
  /// **'Choose a pickup time'**
  String get guestOrderChoosePickup;

  /// Card on the order screen for a pre-order: the chosen pickup slot; day is like Sat, 3 Oct and time like 7:30 PM
  ///
  /// In en, this message translates to:
  /// **'Pickup on {day} • {time}'**
  String guestOrderPickupOn({required String day, required String time});

  /// Small word at the end of the pickup slot card
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get guestOrderChange;

  /// Hint of the name field for a delivery order
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get guestOrderYourName;

  /// Hint of the address field for a delivery order
  ///
  /// In en, this message translates to:
  /// **'Address or room number'**
  String get guestOrderAddressHint;

  /// Count of portions in the order, top of the wide order panel
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String guestOrderItemCount({required int count});

  /// Empty state heading of the wide order panel
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get guestOrderPanelEmptyTitle;

  /// Empty state line of the wide order panel
  ///
  /// In en, this message translates to:
  /// **'Swipe a dish right, or tap the heart, and it lands here.'**
  String get guestOrderPanelEmptyBody;

  /// Main button of the wide order panel
  ///
  /// In en, this message translates to:
  /// **'Review and place order'**
  String get guestOrderPanelReview;

  /// Total line of the estimated bill on the order screen and the wide panel (restaurant may override in its storefront copy)
  ///
  /// In en, this message translates to:
  /// **'Estimated total'**
  String get guestOrderEstimatedTotal;

  /// Heading of the pre-order screen
  ///
  /// In en, this message translates to:
  /// **'Select date & time'**
  String get guestPreTitle;

  /// Line under the heading of the pre-order screen
  ///
  /// In en, this message translates to:
  /// **'When would you like to pick up your order?'**
  String get guestPreSubtitle;

  /// Section title above the pickup time chips
  ///
  /// In en, this message translates to:
  /// **'Select a time slot'**
  String get guestPreSlotsTitle;

  /// Shown instead of time chips when the chosen day has no pickup slots
  ///
  /// In en, this message translates to:
  /// **'No pickup times on this day.'**
  String get guestPreNoSlots;

  /// Title of the guest bill screen (restaurant may override in its storefront copy)
  ///
  /// In en, this message translates to:
  /// **'Your bill'**
  String get guestBillTitle;

  /// Button on the guest bill screen that opens the split sheet (restaurant may override in its storefront copy)
  ///
  /// In en, this message translates to:
  /// **'Split bill'**
  String get guestBillSplit;

  /// Line of the bill the guest sees
  ///
  /// In en, this message translates to:
  /// **'Service charge'**
  String get guestBillServiceCharge;

  /// GST line of the bill the guest sees; percent is the rate as a plain number such as 5 or 2.5
  ///
  /// In en, this message translates to:
  /// **'GST ({percent}%)'**
  String guestBillGst({required String percent});

  /// Line of the bill the guest sees: rounding to the nearest rupee
  ///
  /// In en, this message translates to:
  /// **'Round off'**
  String get guestBillRoundOff;

  /// Under the bill title: one placed order's number; number is like VB1252
  ///
  /// In en, this message translates to:
  /// **'Order #{number}'**
  String guestBillOrderNo({required String number});

  /// Note on the bill of a dine-in order when online payment is also offered
  ///
  /// In en, this message translates to:
  /// **'Prefer to pay at the table? Let a member of staff know you\'re ready for the bill. Calling staff from this screen isn\'t available yet.'**
  String get guestBillPayTableOnline;

  /// Note on the bill of a dine-in order when there is no online payment
  ///
  /// In en, this message translates to:
  /// **'To pay at the table, let a member of staff know you\'re ready for the bill. Calling staff from this screen isn\'t available yet.'**
  String get guestBillPayTable;

  /// Note on the bill of a takeaway order when online payment is also offered
  ///
  /// In en, this message translates to:
  /// **'Prefer to pay at the counter? You can pay when you collect your order.'**
  String get guestBillPayCounterOnline;

  /// Note on the bill of a takeaway order when there is no online payment
  ///
  /// In en, this message translates to:
  /// **'Please pay at the counter when you collect your order.'**
  String get guestBillPayCounter;

  /// Main button of the guest bill when online payment is offered; amount is rupees still due
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String guestBillPay({required String amount});

  /// Button on the guest bill: start another round of ordering
  ///
  /// In en, this message translates to:
  /// **'Order more'**
  String get guestBillOrderMore;

  /// Verdict on the bill when the table went over its budget; amount is rupees
  ///
  /// In en, this message translates to:
  /// **'You went {amount} over your budget.'**
  String guestBillOverBudget({required String amount});

  /// Verdict on the bill when the table stayed within its budget
  ///
  /// In en, this message translates to:
  /// **'Great! You stayed within your budget.'**
  String get guestBillWithinBudget;

  /// Button on the guest bill: put the last order back in the cart
  ///
  /// In en, this message translates to:
  /// **'Order the same again'**
  String get guestBillRepeat;

  /// Heading of the bottom sheet that divides the bill between people
  ///
  /// In en, this message translates to:
  /// **'Split the bill'**
  String get guestBillSplitTitle;

  /// Under the stepper of the split-the-bill sheet
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person} other{{count} people}}'**
  String guestBillPeople({required int count});

  /// Large figure of the split-the-bill sheet: each person's share; amount is rupees
  ///
  /// In en, this message translates to:
  /// **'{amount} each'**
  String guestBillEach({required String amount});

  /// Note at the bottom of the split-the-bill sheet
  ///
  /// In en, this message translates to:
  /// **'Staff will settle the bill at the table.'**
  String get guestBillStaffSettle;

  /// Heading of the feedback faces on the guest bill
  ///
  /// In en, this message translates to:
  /// **'How was your experience?'**
  String get guestBillFeedbackTitle;

  /// Feedback face: best rating
  ///
  /// In en, this message translates to:
  /// **'Loved it'**
  String get guestBillFeedbackLoved;

  /// Feedback face: good rating
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get guestBillFeedbackGood;

  /// Feedback face: neutral rating
  ///
  /// In en, this message translates to:
  /// **'Okay'**
  String get guestBillFeedbackOkay;

  /// Feedback face: lowest rating
  ///
  /// In en, this message translates to:
  /// **'Could be better'**
  String get guestBillFeedbackBetter;

  /// Title of the guest payment screen (top bar)
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get guestPayTitle;

  /// Main button on the guest payment screen; amount is the money to pay such as ₹1,090
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String guestPayButton({required String amount});

  /// Line above the Pay button while the mobile number is missing or wrong
  ///
  /// In en, this message translates to:
  /// **'Enter your mobile number to pay'**
  String get guestPayNeedPhone;

  /// Error under the mobile number field when more than 10 digits were typed
  ///
  /// In en, this message translates to:
  /// **'Enter just the 10 digits, without 0 or +91'**
  String get guestPayPhoneTooLong;

  /// Error under the mobile number field when the 10 digits start with the wrong digit
  ///
  /// In en, this message translates to:
  /// **'A mobile number starts with 6, 7, 8 or 9'**
  String get guestPayPhoneBadStart;

  /// Guest payment screen when the restaurant cannot take online payments or there is no order to pay
  ///
  /// In en, this message translates to:
  /// **'Online payment is not set up here. Please ask a member of staff for the bill.'**
  String get guestPayNotSetUp;

  /// Small line above the big amount when the guest pays only their share of the bill
  ///
  /// In en, this message translates to:
  /// **'Your share'**
  String get guestPayYourShare;

  /// Small line above the big amount when the guest pays the whole bill
  ///
  /// In en, this message translates to:
  /// **'Amount to pay'**
  String get guestPayAmountToPay;

  /// Heading of the red notice after an online payment failed
  ///
  /// In en, this message translates to:
  /// **'The payment didn\'t go through'**
  String get guestPayFailedTitle;

  /// Text of the red notice after a failed online payment when the server gave no reason of its own
  ///
  /// In en, this message translates to:
  /// **'Nothing has been paid. You can try again, or ask a member of staff to take the payment.'**
  String get guestPayFailedBody;

  /// Heading of the notice shown when the guest closed the payment window without paying
  ///
  /// In en, this message translates to:
  /// **'Payment window closed'**
  String get guestPayClosedTitle;

  /// Text of the notice shown after the payment window was closed; Pay is the main button
  ///
  /// In en, this message translates to:
  /// **'Nothing has been paid yet. Tap Pay when you are ready.'**
  String get guestPayClosedBody;

  /// Row that opens the bill lines on the guest payment screen
  ///
  /// In en, this message translates to:
  /// **'See the bill'**
  String get guestPaySeeBill;

  /// Heading of the card that asks the guest for a mobile number before paying online
  ///
  /// In en, this message translates to:
  /// **'Your mobile number'**
  String get guestPayYourMobile;

  /// Helper line under the mobile number field
  ///
  /// In en, this message translates to:
  /// **'The payment service asks for it with every payment.'**
  String get guestPayMobileWhy;

  /// Line telling the guest which ways to pay the payment window offers
  ///
  /// In en, this message translates to:
  /// **'UPI, cards, netbanking or wallets. You choose in the next step.'**
  String get guestPayMethods;

  /// Small footer line on the guest payment screen; Cashfree is the payment gateway's name
  ///
  /// In en, this message translates to:
  /// **'Payments are processed by Cashfree.'**
  String get guestPayProcessedBy;

  /// Choice on the guest payment screen: pay the whole bill
  ///
  /// In en, this message translates to:
  /// **'Whole bill'**
  String get guestPaySplitWhole;

  /// Choice on the guest payment screen: pay only my share of the bill
  ///
  /// In en, this message translates to:
  /// **'My share'**
  String get guestPaySplitMine;

  /// Label before the people stepper when splitting the bill; the stepper and the word people follow it
  ///
  /// In en, this message translates to:
  /// **'Split between'**
  String get guestPaySplitBetween;

  /// Word after the people stepper when splitting the bill
  ///
  /// In en, this message translates to:
  /// **'people'**
  String get guestPayPeople;

  /// Row that opens a QR code so the guest can pay from their own phone
  ///
  /// In en, this message translates to:
  /// **'Pay from your own phone'**
  String get guestPayOwnPhone;

  /// Line under Pay from your own phone while the mobile number is missing
  ///
  /// In en, this message translates to:
  /// **'Enter your mobile number above first.'**
  String get guestPayOwnPhoneNeedNumber;

  /// Line under the payment QR code; amount is the money to pay
  ///
  /// In en, this message translates to:
  /// **'Scan with your camera to pay {amount}'**
  String guestPayScanToPay({required String amount});

  /// Heading of the card over the page while the payment is being set up
  ///
  /// In en, this message translates to:
  /// **'Getting your payment ready'**
  String get guestPayStartingTitle;

  /// Heading of the card over the page while the payment window is open
  ///
  /// In en, this message translates to:
  /// **'Complete your payment'**
  String get guestPayCheckoutTitle;

  /// Text under Complete your payment
  ///
  /// In en, this message translates to:
  /// **'Finish in the payment window. Do not close this page.'**
  String get guestPayCheckoutBody;

  /// Heading of the card over the page while the server checks that the money arrived
  ///
  /// In en, this message translates to:
  /// **'Confirming with your bank'**
  String get guestPayVerifyingTitle;

  /// Text under Confirming with your bank
  ///
  /// In en, this message translates to:
  /// **'This only takes a moment. Please don\'t pay again.'**
  String get guestPayVerifyingBody;

  /// Heading of the card over the page while the bank has not answered yet
  ///
  /// In en, this message translates to:
  /// **'Waiting for your bank'**
  String get guestPayPendingTitle;

  /// Text under Waiting for your bank when the server gave no other reason
  ///
  /// In en, this message translates to:
  /// **'This can take a minute. Please don\'t pay again: this page will update on its own.'**
  String get guestPayPendingBody;

  /// Button on the Waiting for your bank card: ask the server again now
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get guestPayCheckNow;

  /// Title after the whole bill was paid online
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get guestPayReceivedTitle;

  /// Title after the guest paid their share but some of the bill is still due
  ///
  /// In en, this message translates to:
  /// **'Your share is paid'**
  String get guestPayShareTitle;

  /// Line after the whole bill was paid; name is the restaurant
  ///
  /// In en, this message translates to:
  /// **'Thank you for dining with {name}.'**
  String guestPayThanks({required String name});

  /// Line after a share was paid; amount is what is still due, table is the restaurant's word for a table in lower case
  ///
  /// In en, this message translates to:
  /// **'{amount} is still to pay on this {table}.'**
  String guestPayRemaining({required String amount, required String table});

  /// Button after a share was paid: go back to the bill
  ///
  /// In en, this message translates to:
  /// **'Back to the bill'**
  String get guestPayBackToBill;

  /// Big title after Place order (restaurant may override it in its storefront copy)
  ///
  /// In en, this message translates to:
  /// **'Order placed!'**
  String get guestPlacedTitle;

  /// Big title after placing a pre-order
  ///
  /// In en, this message translates to:
  /// **'Pre-order confirmed!'**
  String get guestPlacedPreOrderTitle;

  /// How many items an order holds, in the line under the order number and on the tracking screen
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String guestPlacedItemCount({required int count});

  /// Line on the pre-order confirmation; day is such as Sat, 16 Sep and time such as 7:30 PM
  ///
  /// In en, this message translates to:
  /// **'Pickup on {day} • {time}'**
  String guestPlacedPickupOn({required String day, required String time});

  /// Small title of the card on the order placed screen that says how long the kitchen needs
  ///
  /// In en, this message translates to:
  /// **'Estimated serving time'**
  String get guestPlacedEstimateTitle;

  /// A range of minutes such as 15–20 minutes, on the order placed and tracking screens
  ///
  /// In en, this message translates to:
  /// **'{low}–{high} minutes'**
  String guestPlacedEstimateRange({required int low, required int high});

  /// Main button on the order placed screen that opens live tracking
  ///
  /// In en, this message translates to:
  /// **'Track order'**
  String get guestPlacedTrackOrder;

  /// Main button on the pre-order confirmation
  ///
  /// In en, this message translates to:
  /// **'View pre-order'**
  String get guestPlacedViewPreOrder;

  /// Main button on the order placed screen when live tracking is off
  ///
  /// In en, this message translates to:
  /// **'View order details'**
  String get guestPlacedViewDetails;

  /// Second button on the pre-order confirmation
  ///
  /// In en, this message translates to:
  /// **'Order something else'**
  String get guestPlacedOrderElse;

  /// Second button on the order placed screen
  ///
  /// In en, this message translates to:
  /// **'Continue exploring'**
  String get guestPlacedContinue;

  /// Big title when a dine-in order has been served
  ///
  /// In en, this message translates to:
  /// **'Your order is served!'**
  String get guestPlacedServedTitle;

  /// Big title when a takeaway or delivery order is ready
  ///
  /// In en, this message translates to:
  /// **'Your order is ready!'**
  String get guestPlacedReadyTitle;

  /// Line under the served title
  ///
  /// In en, this message translates to:
  /// **'Hope you enjoy your meal.'**
  String get guestPlacedEnjoy;

  /// Button that opens the guest's bill (served screen and live tracking)
  ///
  /// In en, this message translates to:
  /// **'View bill'**
  String get guestPlacedViewBill;

  /// Button that starts another round of ordering (served screen and after paying)
  ///
  /// In en, this message translates to:
  /// **'Order more'**
  String get guestPlacedOrderMore;

  /// Title of the live tracking screen; number is the order number
  ///
  /// In en, this message translates to:
  /// **'Order #{number}'**
  String guestTrackTitle({required String number});

  /// Button shown only in Studio's preview: moves the tracking screen to its next step
  ///
  /// In en, this message translates to:
  /// **'Next step (preview)'**
  String get guestTrackNextPreview;

  /// Card on the tracking screen when the order was cancelled
  ///
  /// In en, this message translates to:
  /// **'This order was cancelled. Please speak to a staff member.'**
  String get guestTrackCancelled;

  /// Label of the card on the tracking screen that says roughly how long is left
  ///
  /// In en, this message translates to:
  /// **'Estimated time'**
  String get guestTrackEstimatedTime;

  /// Link beside Discover more on the tracking screen
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get guestTrackSeeAll;

  /// Under the big step name on the tracking screen
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String guestTrackStepOf({required int step, required int total});

  /// Tracking step 1 name (restaurant may override it in its storefront copy)
  ///
  /// In en, this message translates to:
  /// **'Order confirmed'**
  String get guestTrackConfirmed;

  /// Line under the Order confirmed step
  ///
  /// In en, this message translates to:
  /// **'We have your order'**
  String get guestTrackConfirmedHint;

  /// Tracking step name: the kitchen is cooking (restaurant may override it in its storefront copy)
  ///
  /// In en, this message translates to:
  /// **'In the kitchen'**
  String get guestTrackInKitchen;

  /// Line under the In the kitchen step
  ///
  /// In en, this message translates to:
  /// **'Your food is being prepared'**
  String get guestTrackInKitchenHint;

  /// Tracking step name: the order is ready (restaurant may override it in its storefront copy)
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get guestTrackReady;

  /// Line under the Ready step of a dine-in order
  ///
  /// In en, this message translates to:
  /// **'We\'ll bring it over shortly'**
  String get guestTrackReadyHintTable;

  /// Line under the Ready step of a takeaway order
  ///
  /// In en, this message translates to:
  /// **'Collect it at the counter'**
  String get guestTrackReadyHintCounter;

  /// Tracking step name of a delivery order: packed and waiting for the rider
  ///
  /// In en, this message translates to:
  /// **'Packed'**
  String get guestTrackPacked;

  /// Line under the Packed step
  ///
  /// In en, this message translates to:
  /// **'Waiting for the rider'**
  String get guestTrackPackedHint;

  /// Tracking step name: the order is on its way to the guest
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get guestTrackOnTheWay;

  /// Line under the On the way step of a dine-in order
  ///
  /// In en, this message translates to:
  /// **'Coming to your table'**
  String get guestTrackOnTheWayHintTable;

  /// Line under the On the way step of a delivery order
  ///
  /// In en, this message translates to:
  /// **'Heading to you'**
  String get guestTrackOnTheWayHintDelivery;

  /// Last tracking step of a dine-in order (restaurant may override it in its storefront copy)
  ///
  /// In en, this message translates to:
  /// **'Served'**
  String get guestTrackServed;

  /// Last tracking step of a takeaway order
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get guestTrackPickedUp;

  /// Last tracking step of a delivery order
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get guestTrackDelivered;

  /// Line under the last tracking step
  ///
  /// In en, this message translates to:
  /// **'Enjoy your meal!'**
  String get guestTrackEnjoy;

  /// Who ordered, when the server gives no table label for the alert that shows what a nearby table just ordered
  ///
  /// In en, this message translates to:
  /// **'A table near you'**
  String get guestNearbyTableNearYou;

  /// First line of the nearby-order alert, kept short because it is one line; who is the server's name for the table such as Table 7
  ///
  /// In en, this message translates to:
  /// **'{who} just ordered'**
  String guestNearbyJustOrdered({required String who});

  /// Spoken description of the nearby-order alert for a screen reader; name is the dish and qty how many portions
  ///
  /// In en, this message translates to:
  /// **'{qty, plural, =1{{who} just ordered {name}} other{{who} just ordered {name} ×{qty}}}'**
  String guestNearbyOrderedLabel({
    required int qty,
    required String who,
    required String name,
  });

  /// Spoken description of the nearby-order alert after the guest added the dish; name is the dish
  ///
  /// In en, this message translates to:
  /// **'Added {name} to your order'**
  String guestNearbyAddedLabel({required String name});

  /// Screen reader hint on the nearby-order alert
  ///
  /// In en, this message translates to:
  /// **'Double tap for details'**
  String get guestNearbyOpenHint;

  /// Screen reader action on the nearby-order alert: add the dish to my order
  ///
  /// In en, this message translates to:
  /// **'Add to order'**
  String get guestNearbyAddToOrder;

  /// Close button of the nearby-order alert (tooltip and screen reader label)
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get guestNearbyDismiss;

  /// Shown for a moment on the Add button of a dish after it was added, on the nearby-order alert and on a similar table's order
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get guestNearbyAdded;

  /// Small heading over the row of cards showing what other tables with a similar party ordered
  ///
  /// In en, this message translates to:
  /// **'Tables like yours'**
  String get guestSimilarHeading;

  /// Screen reader hint on a similar table's card
  ///
  /// In en, this message translates to:
  /// **'See what they ordered'**
  String get guestSimilarSeeOrder;

  /// Spoken name of a similar table with how many people sat there; who is the server's name for the table
  ///
  /// In en, this message translates to:
  /// **'{who}, {count, plural, =1{1 person} other{{count} people}}'**
  String guestSimilarWhoParty({required String who, required int count});

  /// Spoken description of a similar table's card: the table, its dishes with counts, and the total
  ///
  /// In en, this message translates to:
  /// **'{who}. {dishes}. Total {total}'**
  String guestSimilarSpoken({
    required String who,
    required String dishes,
    required String total,
  });

  /// How long ago a similar table ordered: under a minute
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get guestSimilarAgoNow;

  /// How long ago a similar table ordered, in minutes
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String guestSimilarAgoMinutes({required int minutes});

  /// How long ago a similar table ordered, in hours
  ///
  /// In en, this message translates to:
  /// **'{hours} hr ago'**
  String guestSimilarAgoHours({required int hours});

  /// How long ago a similar table ordered, in days
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day ago} other{{days} days ago}}'**
  String guestSimilarAgoDays({required int days});

  /// Line under the sheet title saying how many people sat at the other table
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{A table of 1} other{A table of {count}}}'**
  String guestSimilarTableOfParty({required int count});

  /// Title of the sheet showing another table's order; who is the server's name for the table such as Table 5 or a table of 4
  ///
  /// In en, this message translates to:
  /// **'What {who} ordered'**
  String guestSimilarSheetTitle({required String who});

  /// Confirmation after the guest took dishes from another table's order into their own; who is the server's name for the table
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added 1 dish from {who}} other{Added {count} dishes from {who}}}'**
  String guestSimilarAddedFrom({required int count, required String who});

  /// Disabled big button on the similar table sheet while no dish is ticked
  ///
  /// In en, this message translates to:
  /// **'Choose a dish'**
  String get guestSimilarChooseDish;

  /// Big button on the similar table sheet: add the ticked dishes; total is what they cost
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Add 1 dish · {total}} other{Add {count} dishes · {total}}}'**
  String guestSimilarAddAll({required int count, required String total});

  /// Text button under the big button on the similar table sheet: close without adding
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get guestSimilarNotNow;

  /// Under Total on the similar table sheet while no dish is ticked
  ///
  /// In en, this message translates to:
  /// **'Nothing chosen'**
  String get guestSimilarNothingChosen;

  /// Spoken total of the similar table sheet; dishes is such as 3 dishes
  ///
  /// In en, this message translates to:
  /// **'Total {total} for {dishes}'**
  String guestSimilarTotalFor({required String total, required String dishes});

  /// Spoken description of a dish row on the similar table sheet: dish, portions, price
  ///
  /// In en, this message translates to:
  /// **'{name}, {count, plural, =1{1 portion} other{{count} portions}}, {price}'**
  String guestSimilarLineLabel({
    required String name,
    required int count,
    required String price,
  });

  /// Screen reader label of the quantity stepper of a dish on the similar table sheet
  ///
  /// In en, this message translates to:
  /// **'{name} quantity'**
  String guestSimilarQtyLabel({required String name});

  /// Spoken label of the Add button after one dish of a similar table's order was added
  ///
  /// In en, this message translates to:
  /// **'Added {name}'**
  String guestSimilarAddedName({required String name});

  /// Spoken label of the Add button of one dish on the similar table sheet
  ///
  /// In en, this message translates to:
  /// **'Add {name} to my order'**
  String guestSimilarAddNameLabel({required String name});

  /// Dimmed row on the similar table sheet for a dish that left the menu
  ///
  /// In en, this message translates to:
  /// **'No longer available'**
  String get guestSimilarGone;

  /// Spoken description of the row for a dish that left the menu
  ///
  /// In en, this message translates to:
  /// **'No longer available, will not be added'**
  String get guestSimilarGoneLabel;

  /// Failure code guest_pay_web_only: the app build cannot open the payment gateway's window
  ///
  /// In en, this message translates to:
  /// **'Paying online opens in the web version for now. Please ask a member of staff to take the payment.'**
  String get failGuestPayWebOnly;

  /// Failure code guest_pay_unreachable: the payment gateway's script could not be loaded
  ///
  /// In en, this message translates to:
  /// **'We could not reach the payment service. Check your connection and try again, or ask a member of staff to take the payment.'**
  String get failGuestPayUnreachable;

  /// Muted text after the amount spent on the budget ring screen: "₹560 of ₹1,000"
  ///
  /// In en, this message translates to:
  /// **'of {amount}'**
  String guestBudgetOfAmount({required String amount});

  /// Joins the last two items of a list in a sentence (the missing build settings)
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get uiAnd;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
