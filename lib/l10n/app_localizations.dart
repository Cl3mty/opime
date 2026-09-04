import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

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
    Locale('fr'),
  ];

  /// No description provided for @academy_button_completed.
  ///
  /// In fr, this message translates to:
  /// **'Acquis'**
  String get academy_button_completed;

  /// No description provided for @academy_button_mark_completed.
  ///
  /// In fr, this message translates to:
  /// **'Marquer comme acquis'**
  String get academy_button_mark_completed;

  /// No description provided for @academy_disclaimer.
  ///
  /// In fr, this message translates to:
  /// **'Contenu à vocation éducative et de vulgarisation uniquement, pas un conseil en investissement : nous ne sommes pas conseillers en gestion de patrimoine (CGP). Chacun prend ses décisions financières en son âme et conscience — l\'objectif est simplement de donner au plus grand nombre les clés pour décider en connaissance de cause.'**
  String get academy_disclaimer;

  /// No description provided for @academy_takeaway_title.
  ///
  /// In fr, this message translates to:
  /// **'À retenir'**
  String get academy_takeaway_title;

  /// No description provided for @academy_vocabulary_title.
  ///
  /// In fr, this message translates to:
  /// **'Vocabulaire'**
  String get academy_vocabulary_title;

  /// No description provided for @analyses_benchmark_chart_not_enough_data.
  ///
  /// In fr, this message translates to:
  /// **'Pas assez de données sur cette période'**
  String get analyses_benchmark_chart_not_enough_data;

  /// No description provided for @analyses_stocks_funds_label.
  ///
  /// In fr, this message translates to:
  /// **'Actions & Fonds'**
  String get analyses_stocks_funds_label;

  /// No description provided for @appName.
  ///
  /// In fr, this message translates to:
  /// **'Opime'**
  String get appName;

  /// No description provided for @budget_default_snapshot_name.
  ///
  /// In fr, this message translates to:
  /// **'Budget du {date}'**
  String budget_default_snapshot_name(Object date);

  /// No description provided for @common_active.
  ///
  /// In fr, this message translates to:
  /// **'Actif'**
  String get common_active;

  /// No description provided for @common_add.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get common_add;

  /// No description provided for @common_back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get common_back;

  /// No description provided for @common_cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get common_cancel;

  /// No description provided for @common_category.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get common_category;

  /// No description provided for @common_close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get common_close;

  /// No description provided for @common_confirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get common_confirm;

  /// No description provided for @common_create.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get common_create;

  /// No description provided for @common_date.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get common_date;

  /// No description provided for @common_delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get common_delete;

  /// No description provided for @common_description.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get common_description;

  /// No description provided for @common_edit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get common_edit;

  /// No description provided for @common_error.
  ///
  /// In fr, this message translates to:
  /// **'Erreur'**
  String get common_error;

  /// No description provided for @common_loading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement...'**
  String get common_loading;

  /// No description provided for @common_name.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get common_name;

  /// No description provided for @common_next.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get common_next;

  /// No description provided for @common_no.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get common_no;

  /// No description provided for @common_none.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get common_none;

  /// No description provided for @common_ok.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get common_ok;

  /// No description provided for @common_open.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir'**
  String get common_open;

  /// No description provided for @common_page_not_found.
  ///
  /// In fr, this message translates to:
  /// **'Page introuvable'**
  String get common_page_not_found;

  /// No description provided for @common_principal.
  ///
  /// In fr, this message translates to:
  /// **'Principal'**
  String get common_principal;

  /// No description provided for @common_remove.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get common_remove;

  /// No description provided for @common_rename.
  ///
  /// In fr, this message translates to:
  /// **'Renommer'**
  String get common_rename;

  /// No description provided for @common_reset.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser'**
  String get common_reset;

  /// No description provided for @common_save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get common_save;

  /// No description provided for @common_search.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get common_search;

  /// No description provided for @common_see.
  ///
  /// In fr, this message translates to:
  /// **'Voir'**
  String get common_see;

  /// No description provided for @common_switch.
  ///
  /// In fr, this message translates to:
  /// **'Basculer'**
  String get common_switch;

  /// No description provided for @common_title.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get common_title;

  /// No description provided for @common_total.
  ///
  /// In fr, this message translates to:
  /// **'TOTAL'**
  String get common_total;

  /// No description provided for @common_yes.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get common_yes;

  /// No description provided for @dashboard_allocation_title.
  ///
  /// In fr, this message translates to:
  /// **'Allocation'**
  String get dashboard_allocation_title;

  /// No description provided for @dashboard_assets_label.
  ///
  /// In fr, this message translates to:
  /// **'Actifs'**
  String get dashboard_assets_label;

  /// No description provided for @dashboard_assets_title.
  ///
  /// In fr, this message translates to:
  /// **'Actifs'**
  String get dashboard_assets_title;

  /// No description provided for @dashboard_liabilities_label.
  ///
  /// In fr, this message translates to:
  /// **'Passifs'**
  String get dashboard_liabilities_label;

  /// No description provided for @dashboard_not_enough_data_period.
  ///
  /// In fr, this message translates to:
  /// **'Pas assez de données sur cette période'**
  String get dashboard_not_enough_data_period;

  /// No description provided for @dashboard_onboarding_cta_hint.
  ///
  /// In fr, this message translates to:
  /// **'Clique ici pour commencer'**
  String get dashboard_onboarding_cta_hint;

  /// No description provided for @dashboard_onboarding_empty_description.
  ///
  /// In fr, this message translates to:
  /// **'Ajoute tes comptes, investissements et crédits pour voir apparaître ton patrimoine, ton allocation et leur évolution. Ça se passe avec le bouton « Compléter mon patrimoine », en haut de l\'écran.'**
  String get dashboard_onboarding_empty_description;

  /// No description provided for @dashboard_onboarding_empty_title.
  ///
  /// In fr, this message translates to:
  /// **'Ton tableau de bord est vide'**
  String get dashboard_onboarding_empty_title;

  /// No description provided for @investments_add_transaction_submit.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter la transaction'**
  String get investments_add_transaction_submit;

  /// No description provided for @investments_add_transaction_title.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une transaction'**
  String get investments_add_transaction_title;

  /// No description provided for @investments_amount_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Montant : —'**
  String get investments_amount_placeholder;

  /// No description provided for @investments_amount_value.
  ///
  /// In fr, this message translates to:
  /// **'Montant : {amount}'**
  String investments_amount_value(String amount);

  /// No description provided for @investments_amount_with_bought_quantity.
  ///
  /// In fr, this message translates to:
  /// **'Montant : {amount} → quantité achetée : {quantity}'**
  String investments_amount_with_bought_quantity(
    String amount,
    String quantity,
  );

  /// No description provided for @investments_delay_days.
  ///
  /// In fr, this message translates to:
  /// **'{days, plural, =1{1 jour} other{{days} jours}}'**
  String investments_delay_days(int days);

  /// No description provided for @investments_delay_months.
  ///
  /// In fr, this message translates to:
  /// **'{months} mois'**
  String investments_delay_months(int months);

  /// No description provided for @investments_delay_years.
  ///
  /// In fr, this message translates to:
  /// **'{years} ans'**
  String investments_delay_years(int years);

  /// No description provided for @investments_delete_linked_transaction_message.
  ///
  /// In fr, this message translates to:
  /// **'Cette transaction fait partie d\'un transfert/arbitrage : sa contrepartie sera aussi supprimée. Cette action est irréversible et modifiera la quantité détenue et le PRU des deux positions concernées.'**
  String get investments_delete_linked_transaction_message;

  /// No description provided for @investments_delete_transaction_message.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible et modifiera la quantité détenue et le PRU de \"{label}\".'**
  String investments_delete_transaction_message(String label);

  /// No description provided for @investments_delete_transaction_title.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette transaction ?'**
  String get investments_delete_transaction_title;

  /// No description provided for @investments_edit_arbitrage_title.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'arbitrage'**
  String get investments_edit_arbitrage_title;

  /// No description provided for @investments_edit_impossible_title.
  ///
  /// In fr, this message translates to:
  /// **'Modification impossible'**
  String get investments_edit_impossible_title;

  /// No description provided for @investments_edit_transaction_title.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la transaction — {label}'**
  String investments_edit_transaction_title(String label);

  /// No description provided for @investments_error_buy_price_must_be_positive.
  ///
  /// In fr, this message translates to:
  /// **'Le prix d\'achat doit être un nombre supérieur à 0.'**
  String get investments_error_buy_price_must_be_positive;

  /// No description provided for @investments_error_date_required.
  ///
  /// In fr, this message translates to:
  /// **'La date est requise.'**
  String get investments_error_date_required;

  /// No description provided for @investments_error_quantity_exceeds_sellable.
  ///
  /// In fr, this message translates to:
  /// **'La quantité ({quantity}) dépasse la quantité qui serait détenue ({maxSellable}).'**
  String investments_error_quantity_exceeds_sellable(
    String quantity,
    String maxSellable,
  );

  /// No description provided for @investments_error_quantity_must_be_positive.
  ///
  /// In fr, this message translates to:
  /// **'La quantité doit être un nombre supérieur à 0.'**
  String get investments_error_quantity_must_be_positive;

  /// No description provided for @investments_error_sell_price_must_be_positive.
  ///
  /// In fr, this message translates to:
  /// **'Le prix de vente doit être un nombre supérieur à 0.'**
  String get investments_error_sell_price_must_be_positive;

  /// No description provided for @investments_estimate_button.
  ///
  /// In fr, this message translates to:
  /// **'Estimer'**
  String get investments_estimate_button;

  /// No description provided for @investments_field_amount_currency.
  ///
  /// In fr, this message translates to:
  /// **'Montant ({currency})'**
  String investments_field_amount_currency(String currency);

  /// No description provided for @investments_field_amount_eur.
  ///
  /// In fr, this message translates to:
  /// **'Montant (€)'**
  String get investments_field_amount_eur;

  /// No description provided for @investments_field_amount_paid_eur.
  ///
  /// In fr, this message translates to:
  /// **'Montant versé (€)'**
  String get investments_field_amount_paid_eur;

  /// No description provided for @investments_field_buy_price.
  ///
  /// In fr, this message translates to:
  /// **'Prix d\'achat'**
  String get investments_field_buy_price;

  /// No description provided for @investments_field_currency_pair_rate.
  ///
  /// In fr, this message translates to:
  /// **'Cours de la paire de devise'**
  String get investments_field_currency_pair_rate;

  /// No description provided for @investments_field_position.
  ///
  /// In fr, this message translates to:
  /// **'Position'**
  String get investments_field_position;

  /// No description provided for @investments_field_quantity.
  ///
  /// In fr, this message translates to:
  /// **'Quantité'**
  String get investments_field_quantity;

  /// No description provided for @investments_field_sell_price.
  ///
  /// In fr, this message translates to:
  /// **'Prix de vente'**
  String get investments_field_sell_price;

  /// No description provided for @investments_field_shares_options_count.
  ///
  /// In fr, this message translates to:
  /// **'Nombre de titres/options'**
  String get investments_field_shares_options_count;

  /// No description provided for @investments_field_total_amount_eur.
  ///
  /// In fr, this message translates to:
  /// **'Montant total (€)'**
  String get investments_field_total_amount_eur;

  /// No description provided for @investments_field_unit_price.
  ///
  /// In fr, this message translates to:
  /// **'Prix unitaire'**
  String get investments_field_unit_price;

  /// No description provided for @investments_fiscal_advantage_active_since.
  ///
  /// In fr, this message translates to:
  /// **'Avantage fiscal actif depuis le {date}'**
  String investments_fiscal_advantage_active_since(String date);

  /// No description provided for @investments_fiscal_advantage_upcoming.
  ///
  /// In fr, this message translates to:
  /// **'Avantage fiscal le {date} (dans {delay})'**
  String investments_fiscal_advantage_upcoming(String date, String delay);

  /// No description provided for @investments_fx_converted_amount.
  ///
  /// In fr, this message translates to:
  /// **'Montant ≈ {amount}'**
  String investments_fx_converted_amount(String amount);

  /// No description provided for @investments_fx_rate_automatic_button.
  ///
  /// In fr, this message translates to:
  /// **'Automatique'**
  String get investments_fx_rate_automatic_button;

  /// No description provided for @investments_fx_rate_display.
  ///
  /// In fr, this message translates to:
  /// **'1 {currency} ≈ {rate} €'**
  String investments_fx_rate_display(String currency, String rate);

  /// No description provided for @investments_fx_rate_manual_button.
  ///
  /// In fr, this message translates to:
  /// **'Taux manuel'**
  String get investments_fx_rate_manual_button;

  /// No description provided for @investments_fx_rate_manual_hint.
  ///
  /// In fr, this message translates to:
  /// **'Taux de change (1 {currency} en €)'**
  String investments_fx_rate_manual_hint(String currency);

  /// No description provided for @investments_fx_rate_searching.
  ///
  /// In fr, this message translates to:
  /// **'Recherche du taux de change…'**
  String get investments_fx_rate_searching;

  /// No description provided for @investments_identifier_choose_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Choisir...'**
  String get investments_identifier_choose_placeholder;

  /// No description provided for @investments_identifier_generic_hint.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant (ISIN, ou libre : adresse, référence...)'**
  String get investments_identifier_generic_hint;

  /// No description provided for @investments_identifier_isin_optional_hint.
  ///
  /// In fr, this message translates to:
  /// **'ISIN (optionnel : laisse vide si le fonds n\'en a pas)'**
  String get investments_identifier_isin_optional_hint;

  /// No description provided for @investments_identifier_optional_hint.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant (optionnel : laisse vide si le fonds n\'en a pas)'**
  String get investments_identifier_optional_hint;

  /// No description provided for @investments_identifier_reference_hint.
  ///
  /// In fr, this message translates to:
  /// **'Référence (optionnelle : numéro de série, référence...)'**
  String get investments_identifier_reference_hint;

  /// No description provided for @investments_mwr_annualized.
  ///
  /// In fr, this message translates to:
  /// **'{percent} par an (MWR, rendement pondéré par vos apports)'**
  String investments_mwr_annualized(String percent);

  /// No description provided for @investments_mwr_since_start.
  ///
  /// In fr, this message translates to:
  /// **'{percent} depuis le début (MWR, moins d\'un an de recul)'**
  String investments_mwr_since_start(String percent);

  /// No description provided for @investments_net_invested_amount_pending_price.
  ///
  /// In fr, this message translates to:
  /// **'Montant net investi (cours pas encore disponible pour tous les investissements)'**
  String get investments_net_invested_amount_pending_price;

  /// No description provided for @investments_new_position_option.
  ///
  /// In fr, this message translates to:
  /// **'+ Nouvelle position'**
  String get investments_new_position_option;

  /// No description provided for @investments_no_data_yet.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de données.'**
  String get investments_no_data_yet;

  /// No description provided for @investments_no_transactions_yet.
  ///
  /// In fr, this message translates to:
  /// **'Aucune transaction pour l\'instant.'**
  String get investments_no_transactions_yet;

  /// No description provided for @investments_opened_on.
  ///
  /// In fr, this message translates to:
  /// **'Ouvert le {date}'**
  String investments_opened_on(String date);

  /// No description provided for @investments_price_sync_offline_message.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de mettre à jour les cours et les performances : vérifie ta connexion internet.'**
  String get investments_price_sync_offline_message;

  /// No description provided for @investments_property_type_apartment.
  ///
  /// In fr, this message translates to:
  /// **'Appartement'**
  String get investments_property_type_apartment;

  /// No description provided for @investments_property_type_house.
  ///
  /// In fr, this message translates to:
  /// **'Maison'**
  String get investments_property_type_house;

  /// No description provided for @investments_reestimate_dialog_title.
  ///
  /// In fr, this message translates to:
  /// **'Réestimer la valeur (€/m²)'**
  String get investments_reestimate_dialog_title;

  /// No description provided for @investments_reestimate_missing_fields_error.
  ///
  /// In fr, this message translates to:
  /// **'Renseigne une adresse et une surface.'**
  String get investments_reestimate_missing_fields_error;

  /// No description provided for @investments_reestimate_no_comparable_sale_error.
  ///
  /// In fr, this message translates to:
  /// **'Aucune vente comparable trouvée pour cette adresse.'**
  String get investments_reestimate_no_comparable_sale_error;

  /// No description provided for @investments_save_error.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'enregistrement : {error}'**
  String investments_save_error(String error);

  /// No description provided for @investments_surface_m2_label.
  ///
  /// In fr, this message translates to:
  /// **'Surface (m²)'**
  String get investments_surface_m2_label;

  /// No description provided for @investments_valuation_last_known_price.
  ///
  /// In fr, this message translates to:
  /// **'Valorisation au dernier cours connu'**
  String get investments_valuation_last_known_price;

  /// No description provided for @liabilities_delete_confirm_message.
  ///
  /// In fr, this message translates to:
  /// **'Ce passif sera définitivement supprimé.'**
  String get liabilities_delete_confirm_message;

  /// No description provided for @liabilities_delete_confirm_title.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer \"{name}\" ?'**
  String liabilities_delete_confirm_title(String name);

  /// No description provided for @liabilities_paid_off.
  ///
  /// In fr, this message translates to:
  /// **'Soldé'**
  String get liabilities_paid_off;

  /// No description provided for @liabilities_remaining_balance_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Capital restant dû, sur {amount} empruntés'**
  String liabilities_remaining_balance_subtitle(String amount);

  /// No description provided for @nav_academy.
  ///
  /// In fr, this message translates to:
  /// **'Académie'**
  String get nav_academy;

  /// No description provided for @nav_analyses.
  ///
  /// In fr, this message translates to:
  /// **'Analyses'**
  String get nav_analyses;

  /// No description provided for @nav_assets.
  ///
  /// In fr, this message translates to:
  /// **'Actifs'**
  String get nav_assets;

  /// No description provided for @nav_assistant.
  ///
  /// In fr, this message translates to:
  /// **'Assistant'**
  String get nav_assistant;

  /// No description provided for @nav_budget.
  ///
  /// In fr, this message translates to:
  /// **'Budget'**
  String get nav_budget;

  /// No description provided for @nav_budget_allocation.
  ///
  /// In fr, this message translates to:
  /// **'Ventilation'**
  String get nav_budget_allocation;

  /// No description provided for @nav_budget_tracking.
  ///
  /// In fr, this message translates to:
  /// **'Suivi'**
  String get nav_budget_tracking;

  /// No description provided for @nav_dashboard.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de bord'**
  String get nav_dashboard;

  /// No description provided for @nav_entities.
  ///
  /// In fr, this message translates to:
  /// **'Entités'**
  String get nav_entities;

  /// No description provided for @nav_home.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get nav_home;

  /// No description provided for @nav_liabilities.
  ///
  /// In fr, this message translates to:
  /// **'Passifs'**
  String get nav_liabilities;

  /// No description provided for @nav_patrimoine.
  ///
  /// In fr, this message translates to:
  /// **'Patrimoine'**
  String get nav_patrimoine;

  /// No description provided for @nav_professional.
  ///
  /// In fr, this message translates to:
  /// **'Professionnel'**
  String get nav_professional;

  /// No description provided for @nav_projects.
  ///
  /// In fr, this message translates to:
  /// **'Projets'**
  String get nav_projects;

  /// No description provided for @nav_settings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get nav_settings;

  /// No description provided for @nav_simulation.
  ///
  /// In fr, this message translates to:
  /// **'Simulation'**
  String get nav_simulation;

  /// No description provided for @nav_simulation_real_estate.
  ///
  /// In fr, this message translates to:
  /// **'Immobilier'**
  String get nav_simulation_real_estate;

  /// No description provided for @nav_simulation_taxation.
  ///
  /// In fr, this message translates to:
  /// **'Fiscalité'**
  String get nav_simulation_taxation;

  /// No description provided for @nav_simulation_transmission.
  ///
  /// In fr, this message translates to:
  /// **'Transmission'**
  String get nav_simulation_transmission;

  /// No description provided for @nav_simulation_wealth.
  ///
  /// In fr, this message translates to:
  /// **'Patrimoine'**
  String get nav_simulation_wealth;

  /// No description provided for @nav_strategy.
  ///
  /// In fr, this message translates to:
  /// **'Stratégie'**
  String get nav_strategy;

  /// No description provided for @nav_tools.
  ///
  /// In fr, this message translates to:
  /// **'Outils'**
  String get nav_tools;

  /// No description provided for @settings_account_name_hint.
  ///
  /// In fr, this message translates to:
  /// **'Nom (ex: Camille)'**
  String get settings_account_name_hint;

  /// No description provided for @settings_add_account.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un compte'**
  String get settings_add_account;

  /// No description provided for @settings_add_vault.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un coffre-fort'**
  String get settings_add_vault;

  /// No description provided for @settings_api_key.
  ///
  /// In fr, this message translates to:
  /// **'Clé API {provider}'**
  String settings_api_key(String provider);

  /// No description provided for @settings_api_key_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Colle ta clé API ici'**
  String get settings_api_key_placeholder;

  /// No description provided for @settings_appearance.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get settings_appearance;

  /// No description provided for @settings_assistant.
  ///
  /// In fr, this message translates to:
  /// **'Assistant IA'**
  String get settings_assistant;

  /// No description provided for @settings_checking_releases.
  ///
  /// In fr, this message translates to:
  /// **'Vérification des releases GitHub...'**
  String get settings_checking_releases;

  /// No description provided for @settings_cloud_description.
  ///
  /// In fr, this message translates to:
  /// **'Dialogue avec {provider} via ta propre clé API : analyses du patrimoine, explications pédagogiques, questions sur tes simulations et ta stratégie.'**
  String settings_cloud_description(String provider);

  /// No description provided for @settings_cloud_include_patrimoine.
  ///
  /// In fr, this message translates to:
  /// **' et la synthèse de ton patrimoine'**
  String get settings_cloud_include_patrimoine;

  /// No description provided for @settings_cloud_warning.
  ///
  /// In fr, this message translates to:
  /// **'Avec {provider}, tes messages{includePatrimoine} sont envoyés aux serveurs de ce fournisseur, hors de ta machine.'**
  String settings_cloud_warning(String provider, String includePatrimoine);

  /// No description provided for @settings_comptes.
  ///
  /// In fr, this message translates to:
  /// **'Comptes'**
  String get settings_comptes;

  /// No description provided for @settings_comptes_description.
  ///
  /// In fr, this message translates to:
  /// **'Sépare le patrimoine, le budget et les notes de stratégie de chaque personne du coffre-fort actif.'**
  String get settings_comptes_description;

  /// No description provided for @settings_create_account.
  ///
  /// In fr, this message translates to:
  /// **'Créer le compte'**
  String get settings_create_account;

  /// No description provided for @settings_dark.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get settings_dark;

  /// No description provided for @settings_download_install.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger et installer'**
  String get settings_download_install;

  /// No description provided for @settings_encryption.
  ///
  /// In fr, this message translates to:
  /// **'Chiffrement du coffre-fort'**
  String get settings_encryption;

  /// No description provided for @settings_encryption_disable.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver le chiffrement'**
  String get settings_encryption_disable;

  /// No description provided for @settings_encryption_disabled.
  ///
  /// In fr, this message translates to:
  /// **'Chiffre les données privées de ce coffre-fort avec un mot de passe que tu définis. Les caches publics (cours de marché, données immobilières, loyers...) restent toujours en clair.'**
  String get settings_encryption_disabled;

  /// No description provided for @settings_encryption_enable.
  ///
  /// In fr, this message translates to:
  /// **'Activer le chiffrement'**
  String get settings_encryption_enable;

  /// No description provided for @settings_encryption_enabled.
  ///
  /// In fr, this message translates to:
  /// **'Les données privées de ce coffre-fort (comptes, budget, passifs, projets, notes de stratégie, simulations) sont chiffrées. Le mot de passe est redemandé à chaque lancement de l\'app.'**
  String get settings_encryption_enabled;

  /// No description provided for @settings_encryption_regenerate_key.
  ///
  /// In fr, this message translates to:
  /// **'Générer une nouvelle clé de récupération'**
  String get settings_encryption_regenerate_key;

  /// No description provided for @settings_include_patrimoine_context.
  ///
  /// In fr, this message translates to:
  /// **'Inclure une synthèse de mon patrimoine dans le contexte du modèle'**
  String get settings_include_patrimoine_context;

  /// No description provided for @settings_language.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get settings_language;

  /// No description provided for @settings_language_description.
  ///
  /// In fr, this message translates to:
  /// **'Choisis la langue d\'affichage de l\'application. \"Système\" utilise la langue de ton appareil.'**
  String get settings_language_description;

  /// No description provided for @settings_language_english.
  ///
  /// In fr, this message translates to:
  /// **'Anglais'**
  String get settings_language_english;

  /// No description provided for @settings_language_french.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get settings_language_french;

  /// No description provided for @settings_language_system.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get settings_language_system;

  /// No description provided for @settings_light.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get settings_light;

  /// No description provided for @settings_new_version.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle version détectée : {version}'**
  String settings_new_version(String version);

  /// No description provided for @settings_news.
  ///
  /// In fr, this message translates to:
  /// **'Actualités'**
  String get settings_news;

  /// No description provided for @settings_news_description.
  ///
  /// In fr, this message translates to:
  /// **'Actualités Yahoo Finance pour tes actions/ETF détenus, et alertes de variation de prix (CoinGecko) pour tes cryptomonnaies détenues. Aucune requête réseau n\'est effectuée si désactivé.'**
  String get settings_news_description;

  /// No description provided for @settings_ollama_address.
  ///
  /// In fr, this message translates to:
  /// **'Adresse du serveur Ollama'**
  String get settings_ollama_address;

  /// No description provided for @settings_ollama_description.
  ///
  /// In fr, this message translates to:
  /// **'Dialogue avec un modèle Ollama local (gemma, llama...) : analyses du patrimoine, explications pédagogiques, questions sur tes simulations et ta stratégie. Tout reste sur ta machine — aucune donnée n\'est envoyée en ligne. Ollama doit tourner en arrière-plan (« ollama serve ») et les modèles s\'installent avec « ollama pull <modèle> ».'**
  String get settings_ollama_description;

  /// No description provided for @settings_ollama_reset_default.
  ///
  /// In fr, this message translates to:
  /// **'Rétablir l\'adresse par défaut'**
  String get settings_ollama_reset_default;

  /// No description provided for @settings_profile_name.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get settings_profile_name;

  /// No description provided for @settings_profile_name_hint.
  ///
  /// In fr, this message translates to:
  /// **'Nom (ex: Camille)'**
  String get settings_profile_name_hint;

  /// No description provided for @settings_profile_relationship.
  ///
  /// In fr, this message translates to:
  /// **'Lien de parenté'**
  String get settings_profile_relationship;

  /// No description provided for @settings_profile_relationship_hint.
  ///
  /// In fr, this message translates to:
  /// **'Lien de parenté (ex: Épouse)'**
  String get settings_profile_relationship_hint;

  /// No description provided for @settings_provider.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseur'**
  String get settings_provider;

  /// No description provided for @settings_relation_name.
  ///
  /// In fr, this message translates to:
  /// **'Lien de parenté'**
  String get settings_relation_name;

  /// No description provided for @settings_relationship_hint.
  ///
  /// In fr, this message translates to:
  /// **'Lien de parenté (ex: Épouse)'**
  String get settings_relationship_hint;

  /// No description provided for @settings_remote_version_unknown.
  ///
  /// In fr, this message translates to:
  /// **'Version distante inconnue.'**
  String get settings_remote_version_unknown;

  /// No description provided for @settings_shortcuts.
  ///
  /// In fr, this message translates to:
  /// **'Raccourcis clavier'**
  String get settings_shortcuts;

  /// No description provided for @settings_system.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get settings_system;

  /// No description provided for @settings_tax_parameters.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres fiscaux'**
  String get settings_tax_parameters;

  /// No description provided for @settings_tax_parameters_description.
  ///
  /// In fr, this message translates to:
  /// **'Barèmes, seuils et abattements utilisés par les simulateurs (IR, IFI, démembrement, donation, succession) — à jour toi-même en cas de révision par l\'État.'**
  String get settings_tax_parameters_description;

  /// No description provided for @settings_up_to_date.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes à jour (latest: {version}).'**
  String settings_up_to_date(String version);

  /// No description provided for @settings_update_check_failed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de vérifier les mises à jour pour le moment.'**
  String get settings_update_check_failed;

  /// No description provided for @settings_vault_activate_failed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'activer ce coffre-fort : {error}'**
  String settings_vault_activate_failed(Object error);

  /// No description provided for @settings_vault_add_failed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ajouter un coffre-fort : {error}'**
  String settings_vault_add_failed(Object error);

  /// No description provided for @settings_vault_forget_failed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'oublier ce coffre-fort : {error}'**
  String settings_vault_forget_failed(Object error);

  /// No description provided for @settings_vault_name_hint.
  ///
  /// In fr, this message translates to:
  /// **'Nom du coffre-fort'**
  String get settings_vault_name_hint;

  /// No description provided for @settings_vault_pick_dialog_title.
  ///
  /// In fr, this message translates to:
  /// **'Choisis ou crée un coffre-fort Opime'**
  String get settings_vault_pick_dialog_title;

  /// No description provided for @settings_vaults.
  ///
  /// In fr, this message translates to:
  /// **'Coffres-forts'**
  String get settings_vaults;

  /// No description provided for @settings_vaults_description.
  ///
  /// In fr, this message translates to:
  /// **'Ajoute plusieurs coffres-forts, donne-leur un nom, bascule entre eux et oublie-les sans toucher aux données sur disque.'**
  String get settings_vaults_description;

  /// No description provided for @settings_version_installed.
  ///
  /// In fr, this message translates to:
  /// **'Version installée : {version}'**
  String settings_version_installed(String version);

  /// No description provided for @settings_version_updates.
  ///
  /// In fr, this message translates to:
  /// **'Version et mises à jour'**
  String get settings_version_updates;

  /// No description provided for @settings_view_release.
  ///
  /// In fr, this message translates to:
  /// **'Voir la release'**
  String get settings_view_release;

  /// No description provided for @shell_assistant_response_ready.
  ///
  /// In fr, this message translates to:
  /// **'Réponse de l\'assistant prête'**
  String get shell_assistant_response_ready;

  /// No description provided for @shell_finish_migration_before_export.
  ///
  /// In fr, this message translates to:
  /// **'Termine la migration du coffre-fort avant d\'exporter.'**
  String get shell_finish_migration_before_export;

  /// No description provided for @shell_migration_pending.
  ///
  /// In fr, this message translates to:
  /// **'Migration en attente'**
  String get shell_migration_pending;

  /// No description provided for @shell_no_profile_loaded.
  ///
  /// In fr, this message translates to:
  /// **'Aucun profil chargé'**
  String get shell_no_profile_loaded;

  /// No description provided for @shell_one_response_ready.
  ///
  /// In fr, this message translates to:
  /// **'Une réponse est prête'**
  String get shell_one_response_ready;

  /// No description provided for @shell_profiles_load_failed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les profils. Le dossier Coffre-fort est peut-être encore en cours de synchronisation.'**
  String get shell_profiles_load_failed;

  /// No description provided for @shell_response_interrupted.
  ///
  /// In fr, this message translates to:
  /// **'Réponse interrompue'**
  String get shell_response_interrupted;

  /// No description provided for @shell_response_interrupted_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Le profil ou le coffre-fort a changé pendant la génération.'**
  String get shell_response_interrupted_subtitle;

  /// No description provided for @shell_responses_pending.
  ///
  /// In fr, this message translates to:
  /// **'{count} réponses en attente'**
  String shell_responses_pending(int count);

  /// No description provided for @shell_retry_after_vault_loaded.
  ///
  /// In fr, this message translates to:
  /// **'Réessaie une fois le coffre-fort chargé.'**
  String get shell_retry_after_vault_loaded;

  /// No description provided for @shell_unlock_before_export.
  ///
  /// In fr, this message translates to:
  /// **'Déverrouille ton coffre-fort avant d\'exporter.'**
  String get shell_unlock_before_export;

  /// No description provided for @shell_vault_locked.
  ///
  /// In fr, this message translates to:
  /// **'Coffre-fort verrouillé'**
  String get shell_vault_locked;

  /// No description provided for @sidebar_account.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get sidebar_account;

  /// No description provided for @sidebar_accounts.
  ///
  /// In fr, this message translates to:
  /// **'Comptes'**
  String get sidebar_accounts;

  /// No description provided for @sidebar_collapse.
  ///
  /// In fr, this message translates to:
  /// **'Réduire'**
  String get sidebar_collapse;

  /// No description provided for @sidebar_expand.
  ///
  /// In fr, this message translates to:
  /// **'Étendre'**
  String get sidebar_expand;

  /// No description provided for @sidebar_switch_account.
  ///
  /// In fr, this message translates to:
  /// **'changer de compte'**
  String get sidebar_switch_account;

  /// No description provided for @academy_envelope_ceiling_label.
  ///
  /// In fr, this message translates to:
  /// **'Plafond'**
  String get academy_envelope_ceiling_label;

  /// No description provided for @academy_envelope_good_to_know_title.
  ///
  /// In fr, this message translates to:
  /// **'Bon à savoir'**
  String get academy_envelope_good_to_know_title;

  /// No description provided for @academy_envelope_ideal_for_label.
  ///
  /// In fr, this message translates to:
  /// **'Idéal pour'**
  String get academy_envelope_ideal_for_label;

  /// No description provided for @academy_envelope_liquidity_label.
  ///
  /// In fr, this message translates to:
  /// **'Liquidité'**
  String get academy_envelope_liquidity_label;

  /// No description provided for @academy_envelope_pitfall_label.
  ///
  /// In fr, this message translates to:
  /// **'Piège à éviter — '**
  String get academy_envelope_pitfall_label;

  /// No description provided for @academy_envelope_taxation_label.
  ///
  /// In fr, this message translates to:
  /// **'Fiscalité'**
  String get academy_envelope_taxation_label;

  /// No description provided for @academy_level_avance.
  ///
  /// In fr, this message translates to:
  /// **'Avancé'**
  String get academy_level_avance;

  /// No description provided for @academy_level_debutant.
  ///
  /// In fr, this message translates to:
  /// **'Débutant'**
  String get academy_level_debutant;

  /// No description provided for @academy_level_intermediaire.
  ///
  /// In fr, this message translates to:
  /// **'Intermédiaire'**
  String get academy_level_intermediaire;

  /// No description provided for @academy_progress_summary.
  ///
  /// In fr, this message translates to:
  /// **'{count} / {total} acquises'**
  String academy_progress_summary(int count, int total);

  /// No description provided for @assistant_attach_document_tooltip.
  ///
  /// In fr, this message translates to:
  /// **'Joindre un document (PDF, TXT, MD)'**
  String get assistant_attach_document_tooltip;

  /// No description provided for @assistant_choose_model_first.
  ///
  /// In fr, this message translates to:
  /// **'Choisis d\'abord un modèle'**
  String get assistant_choose_model_first;

  /// No description provided for @assistant_configure_api_key_prompt.
  ///
  /// In fr, this message translates to:
  /// **'Configure ta clé API {provider} dans Réglages → Assistant IA.'**
  String assistant_configure_api_key_prompt(String provider);

  /// No description provided for @assistant_disabled_description.
  ///
  /// In fr, this message translates to:
  /// **'Active l\'assistant dans les Réglages pour analyser ton patrimoine, expliquer des concepts financiers et répondre à tes questions — avec un modèle Ollama local (aucune donnée ne quitte ta machine) ou un fournisseur cloud connecté via une clé API.'**
  String get assistant_disabled_description;

  /// No description provided for @assistant_disabled_title.
  ///
  /// In fr, this message translates to:
  /// **'Assistant IA désactivé'**
  String get assistant_disabled_title;

  /// No description provided for @assistant_document_read_error_generic_title.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la lecture du document'**
  String get assistant_document_read_error_generic_title;

  /// No description provided for @assistant_document_read_error_title.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lire ce document'**
  String get assistant_document_read_error_title;

  /// No description provided for @assistant_document_truncated_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'« {fileName} » dépasse la taille prise en charge : seul le début a été transmis à l\'assistant.'**
  String assistant_document_truncated_subtitle(String fileName);

  /// No description provided for @assistant_document_truncated_title.
  ///
  /// In fr, this message translates to:
  /// **'Document tronqué'**
  String get assistant_document_truncated_title;

  /// No description provided for @assistant_document_truncated_tooltip.
  ///
  /// In fr, this message translates to:
  /// **'Document tronqué : seul le début a été transmis à l\'assistant.'**
  String get assistant_document_truncated_tooltip;

  /// No description provided for @assistant_empty_state_description.
  ///
  /// In fr, this message translates to:
  /// **'Pose une question sur ton patrimoine, tes simulations ou ta stratégie. Les réponses s\'appuient sur tes données locales si l\'option de contexte est activée.'**
  String get assistant_empty_state_description;

  /// No description provided for @assistant_empty_state_title.
  ///
  /// In fr, this message translates to:
  /// **'Que veux-tu savoir ?'**
  String get assistant_empty_state_title;

  /// No description provided for @assistant_error_generic.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : {error}'**
  String assistant_error_generic(String error);

  /// No description provided for @assistant_input_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Pose une question sur ton patrimoine…'**
  String get assistant_input_placeholder;

  /// No description provided for @assistant_model_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Modèle'**
  String get assistant_model_placeholder;

  /// No description provided for @assistant_model_setup_help.
  ///
  /// In fr, this message translates to:
  /// **'Pour activer l\'assistant : installe Ollama depuis ollama.com et lance-le, puis exécute « ollama pull llama3.2 » dans un terminal, et clique sur Actualiser.'**
  String get assistant_model_setup_help;

  /// No description provided for @assistant_multiple_responses_generating.
  ///
  /// In fr, this message translates to:
  /// **'Plusieurs réponses en cours de génération…'**
  String get assistant_multiple_responses_generating;

  /// No description provided for @assistant_new_conversation.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle conversation'**
  String get assistant_new_conversation;

  /// No description provided for @assistant_no_model_cloud.
  ///
  /// In fr, this message translates to:
  /// **'Aucun modèle disponible pour cette clé {provider}.'**
  String assistant_no_model_cloud(String provider);

  /// No description provided for @assistant_no_model_ollama.
  ///
  /// In fr, this message translates to:
  /// **'Aucun modèle n\'est installé sur Ollama.'**
  String get assistant_no_model_ollama;

  /// No description provided for @assistant_open_settings.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les Réglages'**
  String get assistant_open_settings;

  /// No description provided for @assistant_refresh_model_list.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser la liste'**
  String get assistant_refresh_model_list;

  /// No description provided for @assistant_retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get assistant_retry;

  /// No description provided for @assistant_send.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get assistant_send;

  /// No description provided for @assistant_stop_generation.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter la génération'**
  String get assistant_stop_generation;

  /// No description provided for @assistant_suggestion_analyze_patrimoine.
  ///
  /// In fr, this message translates to:
  /// **'Analyse mon patrimoine'**
  String get assistant_suggestion_analyze_patrimoine;

  /// No description provided for @assistant_suggestion_explain_allocation.
  ///
  /// In fr, this message translates to:
  /// **'Explique-moi mon allocation'**
  String get assistant_suggestion_explain_allocation;

  /// No description provided for @assistant_suggestion_simulations_summary.
  ///
  /// In fr, this message translates to:
  /// **'Que disent mes simulations ?'**
  String get assistant_suggestion_simulations_summary;

  /// No description provided for @assistant_suggestion_summarize_strategy.
  ///
  /// In fr, this message translates to:
  /// **'Résume ma stratégie'**
  String get assistant_suggestion_summarize_strategy;

  /// No description provided for @budget_add_category.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une catégorie'**
  String get budget_add_category;

  /// No description provided for @budget_add_revenue_source.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une source de revenu'**
  String get budget_add_revenue_source;

  /// No description provided for @budget_amount_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get budget_amount_placeholder;

  /// No description provided for @budget_bucket_dettes.
  ///
  /// In fr, this message translates to:
  /// **'Dettes'**
  String get budget_bucket_dettes;

  /// No description provided for @budget_bucket_factures.
  ///
  /// In fr, this message translates to:
  /// **'Factures'**
  String get budget_bucket_factures;

  /// No description provided for @budget_bucket_invest_epargne.
  ///
  /// In fr, this message translates to:
  /// **'Invest/Épargne'**
  String get budget_bucket_invest_epargne;

  /// No description provided for @budget_distribution_title.
  ///
  /// In fr, this message translates to:
  /// **'Répartition'**
  String get budget_distribution_title;

  /// No description provided for @budget_duplicate_name_suffix.
  ///
  /// In fr, this message translates to:
  /// **'{name} (copie)'**
  String budget_duplicate_name_suffix(String name);

  /// No description provided for @budget_duplicate_tooltip.
  ///
  /// In fr, this message translates to:
  /// **'Dupliquer ce budget'**
  String get budget_duplicate_tooltip;

  /// No description provided for @budget_history_empty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun budget sauvegardé.'**
  String get budget_history_empty;

  /// No description provided for @budget_history_title.
  ///
  /// In fr, this message translates to:
  /// **'Budgets ventilés'**
  String get budget_history_title;

  /// No description provided for @budget_inout_header.
  ///
  /// In fr, this message translates to:
  /// **'ENTRÉES / SORTIES D\'ARGENT'**
  String get budget_inout_header;

  /// No description provided for @budget_landscape_suggestion.
  ///
  /// In fr, this message translates to:
  /// **'Utilisez l\'application en mode paysage pour une meilleure lisibilité'**
  String get budget_landscape_suggestion;

  /// No description provided for @budget_legend_realite.
  ///
  /// In fr, this message translates to:
  /// **'Réalité'**
  String get budget_legend_realite;

  /// No description provided for @budget_load_error.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les budgets. Vérifiez que le dossier Coffre-fort est accessible.'**
  String get budget_load_error;

  /// No description provided for @budget_month_april.
  ///
  /// In fr, this message translates to:
  /// **'avril'**
  String get budget_month_april;

  /// No description provided for @budget_month_august.
  ///
  /// In fr, this message translates to:
  /// **'août'**
  String get budget_month_august;

  /// No description provided for @budget_month_december.
  ///
  /// In fr, this message translates to:
  /// **'décembre'**
  String get budget_month_december;

  /// No description provided for @budget_month_february.
  ///
  /// In fr, this message translates to:
  /// **'février'**
  String get budget_month_february;

  /// No description provided for @budget_month_flow_title.
  ///
  /// In fr, this message translates to:
  /// **'Flux du mois'**
  String get budget_month_flow_title;

  /// No description provided for @budget_month_january.
  ///
  /// In fr, this message translates to:
  /// **'janvier'**
  String get budget_month_january;

  /// No description provided for @budget_month_july.
  ///
  /// In fr, this message translates to:
  /// **'juillet'**
  String get budget_month_july;

  /// No description provided for @budget_month_june.
  ///
  /// In fr, this message translates to:
  /// **'juin'**
  String get budget_month_june;

  /// No description provided for @budget_month_march.
  ///
  /// In fr, this message translates to:
  /// **'mars'**
  String get budget_month_march;

  /// No description provided for @budget_month_may.
  ///
  /// In fr, this message translates to:
  /// **'mai'**
  String get budget_month_may;

  /// No description provided for @budget_month_november.
  ///
  /// In fr, this message translates to:
  /// **'novembre'**
  String get budget_month_november;

  /// No description provided for @budget_month_october.
  ///
  /// In fr, this message translates to:
  /// **'octobre'**
  String get budget_month_october;

  /// No description provided for @budget_month_september.
  ///
  /// In fr, this message translates to:
  /// **'septembre'**
  String get budget_month_september;

  /// No description provided for @budget_name_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Nom du budget'**
  String get budget_name_placeholder;

  /// No description provided for @budget_new_budget.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau budget'**
  String get budget_new_budget;

  /// No description provided for @budget_no_data.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée'**
  String get budget_no_data;

  /// No description provided for @budget_no_results.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat.'**
  String get budget_no_results;

  /// No description provided for @budget_redo_shortcut_windows.
  ///
  /// In fr, this message translates to:
  /// **'Ctrl+Maj+Z'**
  String get budget_redo_shortcut_windows;

  /// No description provided for @budget_redo_tooltip.
  ///
  /// In fr, this message translates to:
  /// **'Rétablir ({shortcut})'**
  String budget_redo_tooltip(String shortcut);

  /// No description provided for @budget_remaining_amount_label.
  ///
  /// In fr, this message translates to:
  /// **'Montant restant'**
  String get budget_remaining_amount_label;

  /// No description provided for @budget_revenue_name_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Nom du revenu'**
  String get budget_revenue_name_placeholder;

  /// No description provided for @budget_sankey_deficit_label.
  ///
  /// In fr, this message translates to:
  /// **'{label} : {amount} (déficit de {deficit})'**
  String budget_sankey_deficit_label(
    String label,
    String amount,
    String deficit,
  );

  /// No description provided for @budget_sankey_empty_message.
  ///
  /// In fr, this message translates to:
  /// **'Ajoute des revenus, dépenses ou investissements pour voir le flux.'**
  String get budget_sankey_empty_message;

  /// No description provided for @budget_sankey_expense_fallback.
  ///
  /// In fr, this message translates to:
  /// **'Dépense'**
  String get budget_sankey_expense_fallback;

  /// No description provided for @budget_sankey_investment_fallback.
  ///
  /// In fr, this message translates to:
  /// **'Investissement'**
  String get budget_sankey_investment_fallback;

  /// No description provided for @budget_sankey_no_data_fallback.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de données pour ce flux.'**
  String get budget_sankey_no_data_fallback;

  /// No description provided for @budget_sankey_node_label.
  ///
  /// In fr, this message translates to:
  /// **'{label} : {amount}'**
  String budget_sankey_node_label(String label, String amount);

  /// No description provided for @budget_sankey_revenue_fallback.
  ///
  /// In fr, this message translates to:
  /// **'Revenu'**
  String get budget_sankey_revenue_fallback;

  /// No description provided for @budget_sankey_uncategorized.
  ///
  /// In fr, this message translates to:
  /// **'Sans catégorie'**
  String get budget_sankey_uncategorized;

  /// No description provided for @budget_save_chart_dialog_title.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer le graphique'**
  String get budget_save_chart_dialog_title;

  /// No description provided for @budget_saved_toast.
  ///
  /// In fr, this message translates to:
  /// **'Budget sauvegardé'**
  String get budget_saved_toast;

  /// No description provided for @budget_search_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un budget...'**
  String get budget_search_placeholder;

  /// No description provided for @budget_section_depenses.
  ///
  /// In fr, this message translates to:
  /// **'DÉPENSES'**
  String get budget_section_depenses;

  /// No description provided for @budget_section_dettes.
  ///
  /// In fr, this message translates to:
  /// **'DETTES'**
  String get budget_section_dettes;

  /// No description provided for @budget_section_factures.
  ///
  /// In fr, this message translates to:
  /// **'FACTURES'**
  String get budget_section_factures;

  /// No description provided for @budget_section_invest_epargne.
  ///
  /// In fr, this message translates to:
  /// **'INVEST / ÉPARGNE'**
  String get budget_section_invest_epargne;

  /// No description provided for @budget_section_projets.
  ///
  /// In fr, this message translates to:
  /// **'PROJETS'**
  String get budget_section_projets;

  /// No description provided for @budget_section_revenues.
  ///
  /// In fr, this message translates to:
  /// **'REVENUS'**
  String get budget_section_revenues;

  /// No description provided for @budget_summary_available.
  ///
  /// In fr, this message translates to:
  /// **' disponible.'**
  String get budget_summary_available;

  /// No description provided for @budget_summary_expenses.
  ///
  /// In fr, this message translates to:
  /// **', des dépenses de '**
  String get budget_summary_expenses;

  /// No description provided for @budget_summary_inout_title.
  ///
  /// In fr, this message translates to:
  /// **'Sommaire des entrées/sorties'**
  String get budget_summary_inout_title;

  /// No description provided for @budget_summary_intro.
  ///
  /// In fr, this message translates to:
  /// **'Votre taux d\'épargne est de '**
  String get budget_summary_intro;

  /// No description provided for @budget_summary_invest.
  ///
  /// In fr, this message translates to:
  /// **' et investissez '**
  String get budget_summary_invest;

  /// No description provided for @budget_summary_possible_rate.
  ///
  /// In fr, this message translates to:
  /// **' (taux d\'épargne possible : '**
  String get budget_summary_possible_rate;

  /// No description provided for @budget_summary_remaining.
  ///
  /// In fr, this message translates to:
  /// **' tous les mois, il vous reste '**
  String get budget_summary_remaining;

  /// No description provided for @budget_summary_row_depenses.
  ///
  /// In fr, this message translates to:
  /// **'- Dépenses'**
  String get budget_summary_row_depenses;

  /// No description provided for @budget_summary_row_dettes.
  ///
  /// In fr, this message translates to:
  /// **'- Dettes'**
  String get budget_summary_row_dettes;

  /// No description provided for @budget_summary_row_factures.
  ///
  /// In fr, this message translates to:
  /// **'- Factures'**
  String get budget_summary_row_factures;

  /// No description provided for @budget_summary_row_invest.
  ///
  /// In fr, this message translates to:
  /// **'- Invest/Épargne'**
  String get budget_summary_row_invest;

  /// No description provided for @budget_summary_row_projets.
  ///
  /// In fr, this message translates to:
  /// **'- Projets'**
  String get budget_summary_row_projets;

  /// No description provided for @budget_summary_row_remaining.
  ///
  /// In fr, this message translates to:
  /// **'RESTANT'**
  String get budget_summary_row_remaining;

  /// No description provided for @budget_summary_row_revenues.
  ///
  /// In fr, this message translates to:
  /// **'+ Revenus'**
  String get budget_summary_row_revenues;

  /// No description provided for @budget_summary_total_income.
  ///
  /// In fr, this message translates to:
  /// **'). Vous avez un revenu total de '**
  String get budget_summary_total_income;

  /// No description provided for @budget_tab_expenses.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses'**
  String get budget_tab_expenses;

  /// No description provided for @budget_tab_investments.
  ///
  /// In fr, this message translates to:
  /// **'Investissements'**
  String get budget_tab_investments;

  /// No description provided for @budget_tab_revenues.
  ///
  /// In fr, this message translates to:
  /// **'Revenus'**
  String get budget_tab_revenues;

  /// No description provided for @budget_templates_nudge_apply.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter au mois'**
  String get budget_templates_nudge_apply;

  /// No description provided for @budget_templates_nudge_message.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 ligne récurrente disponible — l\'ajouter à ce mois ?} other{{count} lignes récurrentes disponibles — les ajouter à ce mois ?}}'**
  String budget_templates_nudge_message(int count);

  /// No description provided for @budget_tracking_sankey_empty_message.
  ///
  /// In fr, this message translates to:
  /// **'Renseigne des montants dans les colonnes Réalité pour voir le flux de ce mois.'**
  String get budget_tracking_sankey_empty_message;

  /// No description provided for @budget_tracking_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de suivi'**
  String get budget_tracking_subtitle;

  /// No description provided for @budget_undo_tooltip.
  ///
  /// In fr, this message translates to:
  /// **'Annuler ({shortcut})'**
  String budget_undo_tooltip(String shortcut);

  /// No description provided for @common_continue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get common_continue;

  /// No description provided for @common_retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get common_retry;

  /// No description provided for @core_ui_new_vault_kind_prompt.
  ///
  /// In fr, this message translates to:
  /// **'Ce coffre-fort est...'**
  String get core_ui_new_vault_kind_prompt;

  /// No description provided for @core_ui_new_vault_title.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau coffre-fort'**
  String get core_ui_new_vault_title;

  /// No description provided for @core_ui_pick_date.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une date'**
  String get core_ui_pick_date;

  /// No description provided for @core_ui_vault_kind_personal.
  ///
  /// In fr, this message translates to:
  /// **'Personnel'**
  String get core_ui_vault_kind_personal;

  /// No description provided for @dashboard_chart_all_categories.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get dashboard_chart_all_categories;

  /// No description provided for @dashboard_chart_categories_count.
  ///
  /// In fr, this message translates to:
  /// **'{count} classes'**
  String dashboard_chart_categories_count(int count);

  /// No description provided for @dashboard_chart_category_empty.
  ///
  /// In fr, this message translates to:
  /// **'(vide)'**
  String get dashboard_chart_category_empty;

  /// No description provided for @dashboard_column_change.
  ///
  /// In fr, this message translates to:
  /// **'Évolution'**
  String get dashboard_column_change;

  /// No description provided for @dashboard_column_pnl.
  ///
  /// In fr, this message translates to:
  /// **'+/- value'**
  String get dashboard_column_pnl;

  /// No description provided for @dashboard_column_pru.
  ///
  /// In fr, this message translates to:
  /// **'PRU'**
  String get dashboard_column_pru;

  /// No description provided for @dashboard_column_value.
  ///
  /// In fr, this message translates to:
  /// **'Valeur'**
  String get dashboard_column_value;

  /// No description provided for @dashboard_extreme_percent_tooltip.
  ///
  /// In fr, this message translates to:
  /// **'Pourcentage énorme car la période démarre avec un montant très faible (ex : toute première transaction minime) — l\'essentiel de la hausse vient surtout de versements ajoutés depuis, pas d\'une vraie plus-value.'**
  String get dashboard_extreme_percent_tooltip;

  /// No description provided for @dashboard_mwr_tooltip.
  ///
  /// In fr, this message translates to:
  /// **'Rendement calculé en tenant compte du montant et de la date de chaque versement (méthode MWR) : il reflète le rendement réellement perçu.'**
  String get dashboard_mwr_tooltip;

  /// No description provided for @dashboard_patrimoine_brut_label.
  ///
  /// In fr, this message translates to:
  /// **'Patrimoine brut'**
  String get dashboard_patrimoine_brut_label;

  /// No description provided for @dashboard_patrimoine_net_label.
  ///
  /// In fr, this message translates to:
  /// **'Patrimoine net'**
  String get dashboard_patrimoine_net_label;

  /// No description provided for @dashboard_top_assets_title.
  ///
  /// In fr, this message translates to:
  /// **'Mes meilleures performances'**
  String get dashboard_top_assets_title;

  /// No description provided for @dashboard_view_by_account.
  ///
  /// In fr, this message translates to:
  /// **'Par compte'**
  String get dashboard_view_by_account;

  /// No description provided for @dashboard_view_by_investment.
  ///
  /// In fr, this message translates to:
  /// **'Par investissement'**
  String get dashboard_view_by_investment;

  /// No description provided for @entities_accounts_section_title.
  ///
  /// In fr, this message translates to:
  /// **'Comptes'**
  String get entities_accounts_section_title;

  /// No description provided for @entities_add_button.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une entité'**
  String get entities_add_button;

  /// No description provided for @entities_card_diluted_suffix.
  ///
  /// In fr, this message translates to:
  /// **'{percent} % vous revient au final'**
  String entities_card_diluted_suffix(Object percent);

  /// No description provided for @entities_card_net_total.
  ///
  /// In fr, this message translates to:
  /// **'sur {amount} net'**
  String entities_card_net_total(Object amount);

  /// No description provided for @entities_card_ownership_direct.
  ///
  /// In fr, this message translates to:
  /// **'{type} · {percent} % détenu'**
  String entities_card_ownership_direct(String type, String percent);

  /// No description provided for @entities_card_ownership_via_parent.
  ///
  /// In fr, this message translates to:
  /// **'{type} · {percent} % détenu par {parent}'**
  String entities_card_ownership_via_parent(
    String type,
    String percent,
    String parent,
  );

  /// No description provided for @entities_delete_confirm_message.
  ///
  /// In fr, this message translates to:
  /// **'Cette entité sera définitivement supprimée. Ses comptes/passifs existants ne sont pas supprimés, mais ne seront plus rattachés à aucune entité.'**
  String get entities_delete_confirm_message;

  /// No description provided for @entities_detail_load_error.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les comptes de cette entité. Vérifiez que le dossier Coffre-fort est accessible.'**
  String get entities_detail_load_error;

  /// No description provided for @entities_dilution_note.
  ///
  /// In fr, this message translates to:
  /// **'Ne comptez pas la valeur de cette entité dans le bilan de {name} — le lien de possession s\'en charge.'**
  String entities_dilution_note(Object name);

  /// No description provided for @entities_editor_edit_title.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'entité'**
  String get entities_editor_edit_title;

  /// No description provided for @entities_editor_new_title.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle entité'**
  String get entities_editor_new_title;

  /// No description provided for @entities_empty_list_hint.
  ///
  /// In fr, this message translates to:
  /// **'Aucune entité pour l\'instant — ajoute un holding, une société commerciale, une SCI ou un compte pro.'**
  String get entities_empty_list_hint;

  /// No description provided for @entities_included_in_net_worth_hint.
  ///
  /// In fr, this message translates to:
  /// **'Inclus dans votre patrimoine net (Tableau de bord, Analyses).'**
  String get entities_included_in_net_worth_hint;

  /// No description provided for @entities_liabilities_section_title.
  ///
  /// In fr, this message translates to:
  /// **'Passifs'**
  String get entities_liabilities_section_title;

  /// No description provided for @entities_load_error.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les entités. Vérifiez que le dossier Coffre-fort est accessible.'**
  String get entities_load_error;

  /// No description provided for @entities_name_hint.
  ///
  /// In fr, this message translates to:
  /// **'Nom (ex : Holding Dupont)'**
  String get entities_name_hint;

  /// No description provided for @entities_name_required_error.
  ///
  /// In fr, this message translates to:
  /// **'Le nom est obligatoire.'**
  String get entities_name_required_error;

  /// No description provided for @entities_net_value_label.
  ///
  /// In fr, this message translates to:
  /// **'Valeur nette'**
  String get entities_net_value_label;

  /// No description provided for @entities_no_accounts_yet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte pour l\'instant — utilise \"Compléter mon patrimoine\" en choisissant cette entité.'**
  String get entities_no_accounts_yet;

  /// No description provided for @entities_no_liabilities_yet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun passif pour l\'instant.'**
  String get entities_no_liabilities_yet;

  /// No description provided for @entities_owned_by_label.
  ///
  /// In fr, this message translates to:
  /// **'Détenue par'**
  String get entities_owned_by_label;

  /// No description provided for @entities_owned_by_self.
  ///
  /// In fr, this message translates to:
  /// **'Moi (directement)'**
  String get entities_owned_by_self;

  /// No description provided for @entities_ownership_by_parent.
  ///
  /// In fr, this message translates to:
  /// **'{type} · {percent} % détenu par sa société mère'**
  String entities_ownership_by_parent(String type, String percent);

  /// No description provided for @entities_ownership_by_user.
  ///
  /// In fr, this message translates to:
  /// **'{type} · {percent} % détenu par vous'**
  String entities_ownership_by_user(String type, String percent);

  /// No description provided for @entities_parent_company_fallback.
  ///
  /// In fr, this message translates to:
  /// **'sa société mère'**
  String get entities_parent_company_fallback;

  /// No description provided for @entities_percent_direct_hint.
  ///
  /// In fr, this message translates to:
  /// **'% détenu directement par vous'**
  String get entities_percent_direct_hint;

  /// No description provided for @entities_percent_via_parent_hint.
  ///
  /// In fr, this message translates to:
  /// **'% détenu par {name}'**
  String entities_percent_via_parent_hint(Object name);

  /// No description provided for @entities_total_net_value_label.
  ///
  /// In fr, this message translates to:
  /// **'Valeur nette détenue via les entités professionnelles'**
  String get entities_total_net_value_label;

  /// No description provided for @entities_type_label.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get entities_type_label;

  /// No description provided for @investments_account_description_hint.
  ///
  /// In fr, this message translates to:
  /// **'Description (facultative, ex: Épargne vacances)'**
  String get investments_account_description_hint;

  /// No description provided for @investments_account_has_transactions.
  ///
  /// In fr, this message translates to:
  /// **'contient des transactions'**
  String get investments_account_has_transactions;

  /// No description provided for @investments_account_name_hint_crypto.
  ///
  /// In fr, this message translates to:
  /// **'Nom du compte (ex: Coinbase)'**
  String get investments_account_name_hint_crypto;

  /// No description provided for @investments_account_name_hint_generic.
  ///
  /// In fr, this message translates to:
  /// **'Nom du compte'**
  String get investments_account_name_hint_generic;

  /// No description provided for @investments_account_name_hint_precious_metals.
  ///
  /// In fr, this message translates to:
  /// **'Nom du compte (ex: Coffre personnel)'**
  String get investments_account_name_hint_precious_metals;

  /// No description provided for @investments_account_name_hint_private_equity.
  ///
  /// In fr, this message translates to:
  /// **'Nom du compte (ex: Moonfare)'**
  String get investments_account_name_hint_private_equity;

  /// No description provided for @investments_account_name_hint_real_estate.
  ///
  /// In fr, this message translates to:
  /// **'Nom du compte (ex: Résidence principale)'**
  String get investments_account_name_hint_real_estate;

  /// No description provided for @investments_account_name_hint_savings.
  ///
  /// In fr, this message translates to:
  /// **'Nom du compte (ex: Livret A)'**
  String get investments_account_name_hint_savings;

  /// No description provided for @investments_account_name_hint_stocks.
  ///
  /// In fr, this message translates to:
  /// **'Nom du compte (ex: PEA Boursorama)'**
  String get investments_account_name_hint_stocks;

  /// No description provided for @investments_add_custom_type_label.
  ///
  /// In fr, this message translates to:
  /// **'+ Nouveau type'**
  String get investments_add_custom_type_label;

  /// No description provided for @investments_bank_name_hint.
  ///
  /// In fr, this message translates to:
  /// **'Banque (ex: Boursorama)'**
  String get investments_bank_name_hint;

  /// No description provided for @investments_comment_hint.
  ///
  /// In fr, this message translates to:
  /// **'Commentaire (facultatif)'**
  String get investments_comment_hint;

  /// No description provided for @investments_country_breakdown_title.
  ///
  /// In fr, this message translates to:
  /// **'Répartition par pays'**
  String get investments_country_breakdown_title;

  /// No description provided for @investments_country_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Pays'**
  String get investments_country_placeholder;

  /// No description provided for @investments_create_account_label.
  ///
  /// In fr, this message translates to:
  /// **'Créer le compte'**
  String get investments_create_account_label;

  /// No description provided for @investments_create_investment_label.
  ///
  /// In fr, this message translates to:
  /// **'Créer l\'investissement'**
  String get investments_create_investment_label;

  /// No description provided for @investments_create_liability_label.
  ///
  /// In fr, this message translates to:
  /// **'Créer le passif'**
  String get investments_create_liability_label;

  /// No description provided for @investments_cumulative_funding_number_error.
  ///
  /// In fr, this message translates to:
  /// **'Le funding cumulé doit être un nombre.'**
  String get investments_cumulative_funding_number_error;

  /// No description provided for @investments_delete_account_confirm_message.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte et ses investissements (sans transaction) seront définitivement supprimés.'**
  String get investments_delete_account_confirm_message;

  /// No description provided for @investments_delete_account_confirm_title.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer « {name} » ?'**
  String investments_delete_account_confirm_title(String name);

  /// No description provided for @investments_delete_account_dialog_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Comptes de {establishment} — seuls ceux sans transaction sont supprimables.'**
  String investments_delete_account_dialog_subtitle(String establishment);

  /// No description provided for @investments_delete_account_dialog_title.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer un compte'**
  String get investments_delete_account_dialog_title;

  /// No description provided for @investments_entry_price_label.
  ///
  /// In fr, this message translates to:
  /// **'Prix d\'entrée'**
  String get investments_entry_price_label;

  /// No description provided for @investments_establishment_name_hint.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'établissement (ex: Boursorama)'**
  String get investments_establishment_name_hint;

  /// No description provided for @investments_exercise_deadline_hint.
  ///
  /// In fr, this message translates to:
  /// **'Date limite d\'exercice (facultative)'**
  String get investments_exercise_deadline_hint;

  /// No description provided for @investments_existing_accounts_label.
  ///
  /// In fr, this message translates to:
  /// **'Comptes existants'**
  String get investments_existing_accounts_label;

  /// No description provided for @investments_finish_without_transaction_label.
  ///
  /// In fr, this message translates to:
  /// **'Terminer sans transaction'**
  String get investments_finish_without_transaction_label;

  /// No description provided for @investments_fund_style_hint.
  ///
  /// In fr, this message translates to:
  /// **'Style de gestion (facultatif)'**
  String get investments_fund_style_hint;

  /// No description provided for @investments_fund_style_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Style de gestion'**
  String get investments_fund_style_placeholder;

  /// No description provided for @investments_item_name_hint.
  ///
  /// In fr, this message translates to:
  /// **'Nom (ex : Rolex Submariner)'**
  String get investments_item_name_hint;

  /// No description provided for @investments_label_hint_precious_metals.
  ///
  /// In fr, this message translates to:
  /// **'Libellé (ex: Amundi Physical Gold ETC)'**
  String get investments_label_hint_precious_metals;

  /// No description provided for @investments_label_hint_private_equity.
  ///
  /// In fr, this message translates to:
  /// **'Libellé (ex: Ardian Expansion Fund)'**
  String get investments_label_hint_private_equity;

  /// No description provided for @investments_label_hint_stocks.
  ///
  /// In fr, this message translates to:
  /// **'Libellé (ex: TotalEnergies)'**
  String get investments_label_hint_stocks;

  /// No description provided for @investments_leverage_hint.
  ///
  /// In fr, this message translates to:
  /// **'Levier (ex : 2)'**
  String get investments_leverage_hint;

  /// No description provided for @investments_leveraged_edit_title.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la position'**
  String get investments_leveraged_edit_title;

  /// No description provided for @investments_leveraged_entry_fx_rate_required_error.
  ///
  /// In fr, this message translates to:
  /// **'Le taux de change du prix d\'entrée est requis.'**
  String get investments_leveraged_entry_fx_rate_required_error;

  /// No description provided for @investments_leveraged_entry_price_positive_error.
  ///
  /// In fr, this message translates to:
  /// **'Le prix d\'entrée doit être un nombre supérieur à 0.'**
  String get investments_leveraged_entry_price_positive_error;

  /// No description provided for @investments_leveraged_estimated_liquidation.
  ///
  /// In fr, this message translates to:
  /// **'Liquidation (estimée) : {amount}'**
  String investments_leveraged_estimated_liquidation(String amount);

  /// No description provided for @investments_leveraged_leverage_positive_error.
  ///
  /// In fr, this message translates to:
  /// **'Le levier doit être un nombre supérieur à 0.'**
  String get investments_leveraged_leverage_positive_error;

  /// No description provided for @investments_leveraged_margin.
  ///
  /// In fr, this message translates to:
  /// **'Marge : {amount}'**
  String investments_leveraged_margin(String amount);

  /// No description provided for @investments_leveraged_market_required_error.
  ///
  /// In fr, this message translates to:
  /// **'Le marché (ex : BTC) est requis.'**
  String get investments_leveraged_market_required_error;

  /// No description provided for @investments_leveraged_new_title.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle position à effet de levier'**
  String get investments_leveraged_new_title;

  /// No description provided for @investments_leveraged_notional_amount.
  ///
  /// In fr, this message translates to:
  /// **'Montant de la position : {amount}'**
  String investments_leveraged_notional_amount(String amount);

  /// No description provided for @investments_leveraged_opening_date_required_error.
  ///
  /// In fr, this message translates to:
  /// **'La date d\'ouverture est requise.'**
  String get investments_leveraged_opening_date_required_error;

  /// No description provided for @investments_leveraged_position_label.
  ///
  /// In fr, this message translates to:
  /// **'Position à effet de levier'**
  String get investments_leveraged_position_label;

  /// No description provided for @investments_leveraged_save_impossible_title.
  ///
  /// In fr, this message translates to:
  /// **'Position impossible à enregistrer'**
  String get investments_leveraged_save_impossible_title;

  /// No description provided for @investments_leveraged_size_positive_error.
  ///
  /// In fr, this message translates to:
  /// **'La taille doit être un nombre supérieur à 0.'**
  String get investments_leveraged_size_positive_error;

  /// No description provided for @investments_linked_asset_label.
  ///
  /// In fr, this message translates to:
  /// **'Bien financé (facultatif)'**
  String get investments_linked_asset_label;

  /// No description provided for @investments_mark_price_positive_error.
  ///
  /// In fr, this message translates to:
  /// **'Le cours doit être un nombre supérieur à 0.'**
  String get investments_mark_price_positive_error;

  /// No description provided for @investments_market_hint.
  ///
  /// In fr, this message translates to:
  /// **'Marché (ex : BTC)'**
  String get investments_market_hint;

  /// No description provided for @investments_market_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Marché'**
  String get investments_market_placeholder;

  /// No description provided for @investments_merge_choose_destination_message.
  ///
  /// In fr, this message translates to:
  /// **'Choisis la position dans laquelle fusionner.'**
  String get investments_merge_choose_destination_message;

  /// No description provided for @investments_merge_dialog_description.
  ///
  /// In fr, this message translates to:
  /// **'Pour corriger une même position saisie deux fois sous des noms différents — pas pour un vrai mouvement financier (voir \"Arbitrer\" pour ça). Toutes les transactions de \"{label}\" sont déplacées telles quelles (mêmes dates, quantités, prix) vers la position choisie ci-dessous, puis \"{label}\" est supprimée. Cette action est irréversible.'**
  String investments_merge_dialog_description(String label);

  /// No description provided for @investments_merge_dialog_title.
  ///
  /// In fr, this message translates to:
  /// **'Fusionner \"{label}\"'**
  String investments_merge_dialog_title(String label);

  /// No description provided for @investments_merge_impossible_title.
  ///
  /// In fr, this message translates to:
  /// **'Fusion impossible'**
  String get investments_merge_impossible_title;

  /// No description provided for @investments_merge_no_other_position_message.
  ///
  /// In fr, this message translates to:
  /// **'Aucune autre position dans ce compte vers laquelle fusionner.'**
  String get investments_merge_no_other_position_message;

  /// No description provided for @investments_merge_submit_button.
  ///
  /// In fr, this message translates to:
  /// **'Fusionner'**
  String get investments_merge_submit_button;

  /// No description provided for @investments_merge_target_label.
  ///
  /// In fr, this message translates to:
  /// **'Fusionner vers'**
  String get investments_merge_target_label;

  /// No description provided for @investments_new_account_section_label.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau compte'**
  String get investments_new_account_section_label;

  /// No description provided for @investments_new_custom_type_hint.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Vins de collection'**
  String get investments_new_custom_type_hint;

  /// No description provided for @investments_new_custom_type_title.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau type'**
  String get investments_new_custom_type_title;

  /// No description provided for @investments_next_unlock.
  ///
  /// In fr, this message translates to:
  /// **'Prochain déblocage : {amount} le {date}'**
  String investments_next_unlock(String amount, String date);

  /// No description provided for @investments_note_hint.
  ///
  /// In fr, this message translates to:
  /// **'Note (facultative)'**
  String get investments_note_hint;

  /// No description provided for @investments_opening_date_hint.
  ///
  /// In fr, this message translates to:
  /// **'Date d\'ouverture (facultative)'**
  String get investments_opening_date_hint;

  /// No description provided for @investments_opening_date_label.
  ///
  /// In fr, this message translates to:
  /// **'Date d\'ouverture'**
  String get investments_opening_date_label;

  /// No description provided for @investments_real_estate_name_hint.
  ///
  /// In fr, this message translates to:
  /// **'Nom du bien (ex: Appartement Lyon 6e)'**
  String get investments_real_estate_name_hint;

  /// No description provided for @investments_refresh_impossible_title.
  ///
  /// In fr, this message translates to:
  /// **'Actualisation impossible'**
  String get investments_refresh_impossible_title;

  /// No description provided for @investments_revert_to_single_value_label.
  ///
  /// In fr, this message translates to:
  /// **'Revenir à une seule valeur'**
  String get investments_revert_to_single_value_label;

  /// No description provided for @investments_sector_breakdown_title.
  ///
  /// In fr, this message translates to:
  /// **'Répartition par secteur'**
  String get investments_sector_breakdown_title;

  /// No description provided for @investments_sector_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Secteur'**
  String get investments_sector_placeholder;

  /// No description provided for @investments_side_label.
  ///
  /// In fr, this message translates to:
  /// **'Sens'**
  String get investments_side_label;

  /// No description provided for @investments_size_label.
  ///
  /// In fr, this message translates to:
  /// **'Taille'**
  String get investments_size_label;

  /// No description provided for @investments_stop_loss_hint.
  ///
  /// In fr, this message translates to:
  /// **'Stop loss (facultatif)'**
  String get investments_stop_loss_hint;

  /// No description provided for @investments_take_profit_hint.
  ///
  /// In fr, this message translates to:
  /// **'Take profit (facultatif)'**
  String get investments_take_profit_hint;

  /// No description provided for @investments_transaction_buy_label.
  ///
  /// In fr, this message translates to:
  /// **'Achat'**
  String get investments_transaction_buy_label;

  /// No description provided for @investments_transaction_sell_label.
  ///
  /// In fr, this message translates to:
  /// **'Vente'**
  String get investments_transaction_sell_label;

  /// No description provided for @investments_unlock_date_hint.
  ///
  /// In fr, this message translates to:
  /// **'Date de déblocage'**
  String get investments_unlock_date_hint;

  /// No description provided for @investments_unlockable_amount.
  ///
  /// In fr, this message translates to:
  /// **'Déblocable : {unlocked} sur {total}'**
  String investments_unlockable_amount(String unlocked, String total);

  /// No description provided for @investments_unlocked_on_label.
  ///
  /// In fr, this message translates to:
  /// **'Débloqué le'**
  String get investments_unlocked_on_label;

  /// No description provided for @investments_vesting_cliff_hint.
  ///
  /// In fr, this message translates to:
  /// **'Cliff (mois, facultatif)'**
  String get investments_vesting_cliff_hint;

  /// No description provided for @investments_vesting_duration_hint.
  ///
  /// In fr, this message translates to:
  /// **'Durée de vesting (mois, facultatif)'**
  String get investments_vesting_duration_hint;

  /// No description provided for @investments_wizard_account_title.
  ///
  /// In fr, this message translates to:
  /// **'Quel compte ?'**
  String get investments_wizard_account_title;

  /// No description provided for @investments_wizard_add_item_label.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter la pièce'**
  String get investments_wizard_add_item_label;

  /// No description provided for @investments_wizard_asset_class_title.
  ///
  /// In fr, this message translates to:
  /// **'Quelle classe d\'actif ?'**
  String get investments_wizard_asset_class_title;

  /// No description provided for @investments_wizard_asset_item_title.
  ///
  /// In fr, this message translates to:
  /// **'Quel bien ?'**
  String get investments_wizard_asset_item_title;

  /// No description provided for @investments_wizard_asset_label.
  ///
  /// In fr, this message translates to:
  /// **'Un actif'**
  String get investments_wizard_asset_label;

  /// No description provided for @investments_wizard_asset_sublabel.
  ///
  /// In fr, this message translates to:
  /// **'Immobilier, bourse, épargne, crypto...'**
  String get investments_wizard_asset_sublabel;

  /// No description provided for @investments_wizard_continue_label.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get investments_wizard_continue_label;

  /// No description provided for @investments_wizard_create_currency_label.
  ///
  /// In fr, this message translates to:
  /// **'Créer la devise'**
  String get investments_wizard_create_currency_label;

  /// No description provided for @investments_wizard_currency_title.
  ///
  /// In fr, this message translates to:
  /// **'Quelle devise ?'**
  String get investments_wizard_currency_title;

  /// No description provided for @investments_wizard_establishment_title.
  ///
  /// In fr, this message translates to:
  /// **'Quel établissement ?'**
  String get investments_wizard_establishment_title;

  /// No description provided for @investments_wizard_investment_or_currency_title.
  ///
  /// In fr, this message translates to:
  /// **'Quel investissement ou devise ?'**
  String get investments_wizard_investment_or_currency_title;

  /// No description provided for @investments_wizard_investment_title.
  ///
  /// In fr, this message translates to:
  /// **'Quel investissement ?'**
  String get investments_wizard_investment_title;

  /// No description provided for @investments_wizard_item_title.
  ///
  /// In fr, this message translates to:
  /// **'Quelle pièce ?'**
  String get investments_wizard_item_title;

  /// No description provided for @investments_wizard_kind_title.
  ///
  /// In fr, this message translates to:
  /// **'Que voulez-vous compléter ?'**
  String get investments_wizard_kind_title;

  /// No description provided for @investments_wizard_liability_label.
  ///
  /// In fr, this message translates to:
  /// **'Un passif'**
  String get investments_wizard_liability_label;

  /// No description provided for @investments_wizard_liability_sublabel.
  ///
  /// In fr, this message translates to:
  /// **'Prêt immobilier, crédit à la consommation...'**
  String get investments_wizard_liability_sublabel;

  /// No description provided for @investments_wizard_liability_type_title.
  ///
  /// In fr, this message translates to:
  /// **'Quel type de passif ?'**
  String get investments_wizard_liability_type_title;

  /// No description provided for @investments_wizard_new_account_label.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau compte'**
  String get investments_wizard_new_account_label;

  /// No description provided for @investments_wizard_new_asset_item_label.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau bien'**
  String get investments_wizard_new_asset_item_label;

  /// No description provided for @investments_wizard_new_currency_label.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle devise'**
  String get investments_wizard_new_currency_label;

  /// No description provided for @investments_wizard_new_entity_label.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle entité'**
  String get investments_wizard_new_entity_label;

  /// No description provided for @investments_wizard_new_entity_sublabel.
  ///
  /// In fr, this message translates to:
  /// **'Holding, société commerciale, SCI, compte pro...'**
  String get investments_wizard_new_entity_sublabel;

  /// No description provided for @investments_wizard_new_establishment_label.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel établissement'**
  String get investments_wizard_new_establishment_label;

  /// No description provided for @investments_wizard_new_investment_label.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel investissement'**
  String get investments_wizard_new_investment_label;

  /// No description provided for @investments_wizard_new_investment_or_currency_label.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel investissement ou devise'**
  String get investments_wizard_new_investment_or_currency_label;

  /// No description provided for @investments_wizard_new_item_label.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle pièce'**
  String get investments_wizard_new_item_label;

  /// No description provided for @investments_wizard_new_liability_title.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau passif'**
  String get investments_wizard_new_liability_title;

  /// No description provided for @investments_wizard_no_precise_type.
  ///
  /// In fr, this message translates to:
  /// **'Aucun type précis'**
  String get investments_wizard_no_precise_type;

  /// No description provided for @investments_wizard_owner_title.
  ///
  /// In fr, this message translates to:
  /// **'À qui appartient ceci ?'**
  String get investments_wizard_owner_title;

  /// No description provided for @investments_wizard_step_number.
  ///
  /// In fr, this message translates to:
  /// **'Étape {n}'**
  String investments_wizard_step_number(String n);

  /// No description provided for @investments_wizard_step_of_total.
  ///
  /// In fr, this message translates to:
  /// **'Étape {current} sur {total}'**
  String investments_wizard_step_of_total(String current, String total);

  /// No description provided for @investments_wizard_step_preliminary.
  ///
  /// In fr, this message translates to:
  /// **'Étape préalable'**
  String get investments_wizard_step_preliminary;

  /// No description provided for @investments_wizard_toggle_currency.
  ///
  /// In fr, this message translates to:
  /// **'Devise'**
  String get investments_wizard_toggle_currency;

  /// No description provided for @investments_wizard_toggle_investment.
  ///
  /// In fr, this message translates to:
  /// **'Investissement'**
  String get investments_wizard_toggle_investment;

  /// No description provided for @liabilities_deferral_duration_label.
  ///
  /// In fr, this message translates to:
  /// **'Durée du différé (mois)'**
  String get liabilities_deferral_duration_label;

  /// No description provided for @liabilities_deferral_partial.
  ///
  /// In fr, this message translates to:
  /// **'Partielle'**
  String get liabilities_deferral_partial;

  /// No description provided for @liabilities_deferral_total.
  ///
  /// In fr, this message translates to:
  /// **'Totale'**
  String get liabilities_deferral_total;

  /// No description provided for @liabilities_deferral_type_label.
  ///
  /// In fr, this message translates to:
  /// **'Franchise'**
  String get liabilities_deferral_type_label;

  /// No description provided for @liabilities_deferred_loan_label.
  ///
  /// In fr, this message translates to:
  /// **'Prêt différé'**
  String get liabilities_deferred_loan_label;

  /// No description provided for @liabilities_down_payment_hint.
  ///
  /// In fr, this message translates to:
  /// **'Apport (€, 0 si aucun)'**
  String get liabilities_down_payment_hint;

  /// No description provided for @liabilities_installments_count_label.
  ///
  /// In fr, this message translates to:
  /// **'Nombre d\'échéances (mois)'**
  String get liabilities_installments_count_label;

  /// No description provided for @liabilities_interest_rate_label.
  ///
  /// In fr, this message translates to:
  /// **'Taux d\'intérêt (%)'**
  String get liabilities_interest_rate_label;

  /// No description provided for @liabilities_loan_type_amortizing.
  ///
  /// In fr, this message translates to:
  /// **'Amortissable'**
  String get liabilities_loan_type_amortizing;

  /// No description provided for @liabilities_loan_type_in_fine.
  ///
  /// In fr, this message translates to:
  /// **'In fine'**
  String get liabilities_loan_type_in_fine;

  /// No description provided for @liabilities_monthly_insurance_label.
  ///
  /// In fr, this message translates to:
  /// **'Assurance mensuelle (€)'**
  String get liabilities_monthly_insurance_label;

  /// No description provided for @liabilities_name_hint.
  ///
  /// In fr, this message translates to:
  /// **'Nom (ex: Prêt résidence principale)'**
  String get liabilities_name_hint;

  /// No description provided for @liabilities_price_total_label.
  ///
  /// In fr, this message translates to:
  /// **'Prix total (€)'**
  String get liabilities_price_total_label;

  /// No description provided for @liabilities_start_date_label.
  ///
  /// In fr, this message translates to:
  /// **'Date de début'**
  String get liabilities_start_date_label;

  /// No description provided for @navigation_account_activated.
  ///
  /// In fr, this message translates to:
  /// **'Compte activé'**
  String get navigation_account_activated;

  /// No description provided for @navigation_amounts_hide.
  ///
  /// In fr, this message translates to:
  /// **'Masquer les montants'**
  String get navigation_amounts_hide;

  /// No description provided for @navigation_amounts_show.
  ///
  /// In fr, this message translates to:
  /// **'Afficher les montants'**
  String get navigation_amounts_show;

  /// No description provided for @navigation_complete_patrimoine.
  ///
  /// In fr, this message translates to:
  /// **'Compléter mon patrimoine'**
  String get navigation_complete_patrimoine;

  /// No description provided for @navigation_export_download_patrimoine_pdf.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger mon patrimoine (PDF)'**
  String get navigation_export_download_patrimoine_pdf;

  /// No description provided for @navigation_export_tooltip.
  ///
  /// In fr, this message translates to:
  /// **'Exporter'**
  String get navigation_export_tooltip;

  /// No description provided for @navigation_export_transactions_csv_json.
  ///
  /// In fr, this message translates to:
  /// **'Exporter les transactions (JSON/CSV)'**
  String get navigation_export_transactions_csv_json;

  /// No description provided for @navigation_profile_active_toast_title.
  ///
  /// In fr, this message translates to:
  /// **'Profil actif: {name}'**
  String navigation_profile_active_toast_title(Object name);

  /// No description provided for @navigation_vault_activate_failed_toast_title.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'activer ce coffre-fort'**
  String get navigation_vault_activate_failed_toast_title;

  /// No description provided for @navigation_vault_active_toast_title.
  ///
  /// In fr, this message translates to:
  /// **'Coffre-fort actif : {name}'**
  String navigation_vault_active_toast_title(Object name);

  /// No description provided for @navigation_vault_fallback_label.
  ///
  /// In fr, this message translates to:
  /// **'Coffre-fort'**
  String get navigation_vault_fallback_label;

  /// No description provided for @navigation_vault_next.
  ///
  /// In fr, this message translates to:
  /// **'Coffre-fort suivant'**
  String get navigation_vault_next;

  /// No description provided for @navigation_vault_next_named.
  ///
  /// In fr, this message translates to:
  /// **'Coffre-fort suivant : {name}'**
  String navigation_vault_next_named(Object name);

  /// No description provided for @navigation_vault_previous.
  ///
  /// In fr, this message translates to:
  /// **'Coffre-fort précédent'**
  String get navigation_vault_previous;

  /// No description provided for @navigation_vault_previous_named.
  ///
  /// In fr, this message translates to:
  /// **'Coffre-fort précédent : {name}'**
  String navigation_vault_previous_named(Object name);

  /// No description provided for @navigation_vault_switched_toast_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Basculé depuis le sélecteur de compte'**
  String get navigation_vault_switched_toast_subtitle;

  /// No description provided for @notifications_crypto_alert_24h.
  ///
  /// In fr, this message translates to:
  /// **'{symbol} {change} % sur 24h'**
  String notifications_crypto_alert_24h(String symbol, String change);

  /// No description provided for @notifications_crypto_price_line.
  ///
  /// In fr, this message translates to:
  /// **'{name} · {price} €'**
  String notifications_crypto_price_line(String name, String price);

  /// No description provided for @notifications_empty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune actualité pour le moment.'**
  String get notifications_empty;

  /// No description provided for @notifications_news_publisher_line.
  ///
  /// In fr, this message translates to:
  /// **'{publisher} · {time}'**
  String notifications_news_publisher_line(String publisher, String time);

  /// No description provided for @notifications_relative_days.
  ///
  /// In fr, this message translates to:
  /// **'il y a {days} j'**
  String notifications_relative_days(int days);

  /// No description provided for @notifications_relative_hours.
  ///
  /// In fr, this message translates to:
  /// **'il y a {hours} h'**
  String notifications_relative_hours(int hours);

  /// No description provided for @notifications_relative_minutes.
  ///
  /// In fr, this message translates to:
  /// **'il y a {minutes} min'**
  String notifications_relative_minutes(int minutes);

  /// No description provided for @notifications_relative_now.
  ///
  /// In fr, this message translates to:
  /// **'à l\'instant'**
  String get notifications_relative_now;

  /// No description provided for @notifications_title.
  ///
  /// In fr, this message translates to:
  /// **'Actualités'**
  String get notifications_title;

  /// No description provided for @onboarding_change_folder_failed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de changer de dossier : {error}'**
  String onboarding_change_folder_failed(String error);

  /// No description provided for @onboarding_change_vault_folder.
  ///
  /// In fr, this message translates to:
  /// **'Changer de dossier du coffre-fort'**
  String get onboarding_change_vault_folder;

  /// No description provided for @onboarding_choose_password.
  ///
  /// In fr, this message translates to:
  /// **'Choisis un mot de passe.'**
  String get onboarding_choose_password;

  /// No description provided for @onboarding_confirm_new_password.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le nouveau mot de passe'**
  String get onboarding_confirm_new_password;

  /// No description provided for @onboarding_create_folder_failed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de créer le dossier de données : {error}'**
  String onboarding_create_folder_failed(String error);

  /// No description provided for @onboarding_creating.
  ///
  /// In fr, this message translates to:
  /// **'Création...'**
  String get onboarding_creating;

  /// No description provided for @onboarding_description.
  ///
  /// In fr, this message translates to:
  /// **'Choisis où seront stockées tes données. Tu peux commencer en local et déplacer ce dossier vers un service cloud (iCloud, Google Drive, Dropbox...) plus tard.'**
  String get onboarding_description;

  /// No description provided for @onboarding_forgot_password.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get onboarding_forgot_password;

  /// No description provided for @onboarding_migration_interrupted_continue.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai compris, continuer quand même'**
  String get onboarding_migration_interrupted_continue;

  /// No description provided for @onboarding_migration_interrupted_description.
  ///
  /// In fr, this message translates to:
  /// **'Une opération de chiffrement ou déchiffrement de ce coffre-fort a été interrompue avant sa fin (l\'app a peut-être été fermée pendant l\'opération). Certains fichiers privés peuvent être restés dans un ancien état pendant que d\'autres sont déjà à jour.'**
  String get onboarding_migration_interrupted_description;

  /// No description provided for @onboarding_migration_interrupted_recommendation.
  ///
  /// In fr, this message translates to:
  /// **'Recommandé : recommence l\'opération depuis les Réglages (Activer/Désactiver le chiffrement) une fois averti — elle remettra tous les fichiers dans le même état. Si un fichier précis refuse ensuite de se charger, ce sera le signe qu\'il faut le restaurer depuis une sauvegarde.'**
  String get onboarding_migration_interrupted_recommendation;

  /// No description provided for @onboarding_migration_interrupted_title.
  ///
  /// In fr, this message translates to:
  /// **'Chiffrement interrompu'**
  String get onboarding_migration_interrupted_title;

  /// No description provided for @onboarding_new_password.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get onboarding_new_password;

  /// No description provided for @onboarding_password.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get onboarding_password;

  /// No description provided for @onboarding_password_incorrect.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe incorrect.'**
  String get onboarding_password_incorrect;

  /// No description provided for @onboarding_passwords_mismatch.
  ///
  /// In fr, this message translates to:
  /// **'Les deux mots de passe ne correspondent pas.'**
  String get onboarding_passwords_mismatch;

  /// No description provided for @onboarding_pick_location.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un emplacement'**
  String get onboarding_pick_location;

  /// No description provided for @onboarding_recovery_description.
  ///
  /// In fr, this message translates to:
  /// **'Saisis la clé de récupération que tu as reçue à l\'activation du chiffrement.'**
  String get onboarding_recovery_description;

  /// No description provided for @onboarding_recovery_key_hint.
  ///
  /// In fr, this message translates to:
  /// **'Clé de récupération (ex. XXXX-XXXX-XXXX-XXXX)'**
  String get onboarding_recovery_key_hint;

  /// No description provided for @onboarding_recovery_key_incorrect.
  ///
  /// In fr, this message translates to:
  /// **'Clé de récupération incorrecte.'**
  String get onboarding_recovery_key_incorrect;

  /// No description provided for @onboarding_recovery_new_password_description.
  ///
  /// In fr, this message translates to:
  /// **'Ta clé de récupération est valide. Choisis un nouveau mot de passe pour ce coffre-fort.'**
  String get onboarding_recovery_new_password_description;

  /// No description provided for @onboarding_recovery_new_password_title.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get onboarding_recovery_new_password_title;

  /// No description provided for @onboarding_recovery_saving.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement...'**
  String get onboarding_recovery_saving;

  /// No description provided for @onboarding_recovery_set_and_unlock.
  ///
  /// In fr, this message translates to:
  /// **'Définir et déverrouiller'**
  String get onboarding_recovery_set_and_unlock;

  /// No description provided for @onboarding_recovery_title.
  ///
  /// In fr, this message translates to:
  /// **'Récupération du coffre-fort'**
  String get onboarding_recovery_title;

  /// No description provided for @onboarding_recovery_validate_key.
  ///
  /// In fr, this message translates to:
  /// **'Valider la clé'**
  String get onboarding_recovery_validate_key;

  /// No description provided for @onboarding_recovery_verifying.
  ///
  /// In fr, this message translates to:
  /// **'Vérification...'**
  String get onboarding_recovery_verifying;

  /// No description provided for @onboarding_selecting.
  ///
  /// In fr, this message translates to:
  /// **'Sélection en cours...'**
  String get onboarding_selecting;

  /// No description provided for @onboarding_unlock.
  ///
  /// In fr, this message translates to:
  /// **'Déverrouiller'**
  String get onboarding_unlock;

  /// No description provided for @onboarding_unlock_description.
  ///
  /// In fr, this message translates to:
  /// **'Ce coffre-fort est chiffré. Saisis ton mot de passe pour accéder à tes données.'**
  String get onboarding_unlock_description;

  /// No description provided for @onboarding_unlocking.
  ///
  /// In fr, this message translates to:
  /// **'Déverrouillage...'**
  String get onboarding_unlocking;

  /// No description provided for @onboarding_vault_kind_prompt.
  ///
  /// In fr, this message translates to:
  /// **'Ce coffre-fort est...'**
  String get onboarding_vault_kind_prompt;

  /// No description provided for @onboarding_welcome_title.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue sur Opime'**
  String get onboarding_welcome_title;

  /// No description provided for @patrimoine_export_failed_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Le PDF n\'a pas pu être généré ou enregistré : {error}'**
  String patrimoine_export_failed_subtitle(String error);

  /// No description provided for @patrimoine_export_generate_pdf.
  ///
  /// In fr, this message translates to:
  /// **'Générer le PDF'**
  String get patrimoine_export_generate_pdf;

  /// No description provided for @patrimoine_export_save_dialog_title.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer le patrimoine (PDF)'**
  String get patrimoine_export_save_dialog_title;

  /// No description provided for @patrimoine_export_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez les actifs et passifs à inclure dans le PDF.'**
  String get patrimoine_export_subtitle;

  /// No description provided for @patrimoine_export_success_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Le PDF a été enregistré : {path}'**
  String patrimoine_export_success_subtitle(String path);

  /// No description provided for @patrimoine_export_title.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger mon patrimoine'**
  String get patrimoine_export_title;

  /// No description provided for @real_estate_add_document_title.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un document'**
  String get real_estate_add_document_title;

  /// No description provided for @real_estate_add_rent_period_button.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une période'**
  String get real_estate_add_rent_period_button;

  /// No description provided for @real_estate_add_work_item_button.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un poste'**
  String get real_estate_add_work_item_button;

  /// No description provided for @real_estate_add_work_item_title.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un poste de travaux'**
  String get real_estate_add_work_item_title;

  /// No description provided for @real_estate_amount_due_label.
  ///
  /// In fr, this message translates to:
  /// **'Montant dû (loyer + charges)'**
  String get real_estate_amount_due_label;

  /// No description provided for @real_estate_amount_received_label.
  ///
  /// In fr, this message translates to:
  /// **'Montant perçu'**
  String get real_estate_amount_received_label;

  /// No description provided for @real_estate_annual_charges_not_tracked_note.
  ///
  /// In fr, this message translates to:
  /// **'Charges annuelles (taxe foncière, assurance, gestion...) pas encore suivies : le rendement net est identique au brut.'**
  String get real_estate_annual_charges_not_tracked_note;

  /// No description provided for @real_estate_annual_rental_income_label.
  ///
  /// In fr, this message translates to:
  /// **'Revenu locatif annuel'**
  String get real_estate_annual_rental_income_label;

  /// No description provided for @real_estate_cashflow_no_loan_note.
  ///
  /// In fr, this message translates to:
  /// **'Sans prêt lié (voir ci-dessus) : cash-flow calculé achat comptant, sans mensualité de crédit.'**
  String get real_estate_cashflow_no_loan_note;

  /// No description provided for @real_estate_cashflow_with_loan_note.
  ///
  /// In fr, this message translates to:
  /// **'Mensualité de crédit déduite : {amount}.'**
  String real_estate_cashflow_with_loan_note(String amount);

  /// No description provided for @real_estate_continue_button.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get real_estate_continue_button;

  /// No description provided for @real_estate_create_mortgage_loan.
  ///
  /// In fr, this message translates to:
  /// **'Créer un prêt immobilier'**
  String get real_estate_create_mortgage_loan;

  /// No description provided for @real_estate_create_work_loan.
  ///
  /// In fr, this message translates to:
  /// **'Créer un crédit travaux'**
  String get real_estate_create_work_loan;

  /// No description provided for @real_estate_delete_document_message.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier sera définitivement supprimé du coffre-fort.'**
  String get real_estate_delete_document_message;

  /// No description provided for @real_estate_delete_document_title.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer \"{fileName}\" ?'**
  String real_estate_delete_document_title(String fileName);

  /// No description provided for @real_estate_delete_rent_period_message.
  ///
  /// In fr, this message translates to:
  /// **'La période {period} sera définitivement retirée de l\'historique des loyers.'**
  String real_estate_delete_rent_period_message(String period);

  /// No description provided for @real_estate_delete_rent_period_title.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette période ?'**
  String get real_estate_delete_rent_period_title;

  /// No description provided for @real_estate_delete_work_item_message.
  ///
  /// In fr, this message translates to:
  /// **'Ce poste de travaux sera définitivement retiré.'**
  String get real_estate_delete_work_item_message;

  /// No description provided for @real_estate_delete_work_item_title.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer \"{label}\" ?'**
  String real_estate_delete_work_item_title(String label);

  /// No description provided for @real_estate_document_category_invoice.
  ///
  /// In fr, this message translates to:
  /// **'Facture'**
  String get real_estate_document_category_invoice;

  /// No description provided for @real_estate_document_category_other.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get real_estate_document_category_other;

  /// No description provided for @real_estate_document_category_photo.
  ///
  /// In fr, this message translates to:
  /// **'Photo'**
  String get real_estate_document_category_photo;

  /// No description provided for @real_estate_document_category_plan.
  ///
  /// In fr, this message translates to:
  /// **'Plan'**
  String get real_estate_document_category_plan;

  /// No description provided for @real_estate_document_category_receipt.
  ///
  /// In fr, this message translates to:
  /// **'Quittance'**
  String get real_estate_document_category_receipt;

  /// No description provided for @real_estate_document_name_hint.
  ///
  /// In fr, this message translates to:
  /// **'Nom du document (optionnel)'**
  String get real_estate_document_name_hint;

  /// No description provided for @real_estate_documents_filter_all.
  ///
  /// In fr, this message translates to:
  /// **'Tous ({count})'**
  String real_estate_documents_filter_all(int count);

  /// No description provided for @real_estate_documents_title.
  ///
  /// In fr, this message translates to:
  /// **'Documents'**
  String get real_estate_documents_title;

  /// No description provided for @real_estate_gross_yield_label.
  ///
  /// In fr, this message translates to:
  /// **'Rendement brut'**
  String get real_estate_gross_yield_label;

  /// No description provided for @real_estate_link_existing_loan.
  ///
  /// In fr, this message translates to:
  /// **'Lier un crédit existant'**
  String get real_estate_link_existing_loan;

  /// No description provided for @real_estate_linked_loan_summary.
  ///
  /// In fr, this message translates to:
  /// **'{name} · {type} · {balance}'**
  String real_estate_linked_loan_summary(
    String name,
    String type,
    String balance,
  );

  /// No description provided for @real_estate_mark_period_paid_title.
  ///
  /// In fr, this message translates to:
  /// **'Marquer {period} payé'**
  String real_estate_mark_period_paid_title(String period);

  /// No description provided for @real_estate_month_label.
  ///
  /// In fr, this message translates to:
  /// **'Mois'**
  String get real_estate_month_label;

  /// No description provided for @real_estate_monthly_cashflow_label.
  ///
  /// In fr, this message translates to:
  /// **'Cash-flow mensuel : {amount}'**
  String real_estate_monthly_cashflow_label(String amount);

  /// No description provided for @real_estate_net_yield_label.
  ///
  /// In fr, this message translates to:
  /// **'Rendement net'**
  String get real_estate_net_yield_label;

  /// No description provided for @real_estate_no_documents_yet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun document pour l\'instant.'**
  String get real_estate_no_documents_yet;

  /// No description provided for @real_estate_no_rent_periods_yet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun loyer suivi pour l\'instant.'**
  String get real_estate_no_rent_periods_yet;

  /// No description provided for @real_estate_no_work_items_yet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun poste de travaux pour l\'instant.'**
  String get real_estate_no_work_items_yet;

  /// No description provided for @real_estate_not_self_financed.
  ///
  /// In fr, this message translates to:
  /// **'Non autofinancé'**
  String get real_estate_not_self_financed;

  /// No description provided for @real_estate_note_optional_label.
  ///
  /// In fr, this message translates to:
  /// **'Note (facultative)'**
  String get real_estate_note_optional_label;

  /// No description provided for @real_estate_payment_date_label.
  ///
  /// In fr, this message translates to:
  /// **'Date de paiement'**
  String get real_estate_payment_date_label;

  /// No description provided for @real_estate_pricing_address_search_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une adresse...'**
  String get real_estate_pricing_address_search_placeholder;

  /// No description provided for @real_estate_pricing_heatmap_loading_communes.
  ///
  /// In fr, this message translates to:
  /// **'Chargement des communes visibles...'**
  String get real_estate_pricing_heatmap_loading_communes;

  /// No description provided for @real_estate_pricing_heatmap_loading_department_prices.
  ///
  /// In fr, this message translates to:
  /// **'Chargement des prix par département : {loaded} / {total} (mis en cache, la prochaine ouverture sera instantanée)'**
  String real_estate_pricing_heatmap_loading_department_prices(
    int loaded,
    int total,
  );

  /// No description provided for @real_estate_pricing_heatmap_loading_grid.
  ///
  /// In fr, this message translates to:
  /// **'Chargement de la grille fine...'**
  String get real_estate_pricing_heatmap_loading_grid;

  /// No description provided for @real_estate_pricing_heatmap_neighborhood_tooltip_title.
  ///
  /// In fr, this message translates to:
  /// **'Quartier (~{size} m)'**
  String real_estate_pricing_heatmap_neighborhood_tooltip_title(int size);

  /// No description provided for @real_estate_pricing_heatmap_no_data.
  ///
  /// In fr, this message translates to:
  /// **'Pas de donnée'**
  String get real_estate_pricing_heatmap_no_data;

  /// No description provided for @real_estate_pricing_heatmap_rent_commune_only.
  ///
  /// In fr, this message translates to:
  /// **'Le loyer n\'est disponible qu\'à l\'échelle de la commune (granularité native de la source).'**
  String get real_estate_pricing_heatmap_rent_commune_only;

  /// No description provided for @real_estate_pricing_heatmap_sale_count.
  ///
  /// In fr, this message translates to:
  /// **'{count} vente(s)'**
  String real_estate_pricing_heatmap_sale_count(int count);

  /// No description provided for @real_estate_profitability_no_rent_hint.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez des loyers (onglet Loyers) pour calculer la rentabilité de ce bien.'**
  String get real_estate_profitability_no_rent_hint;

  /// No description provided for @real_estate_rent_paid.
  ///
  /// In fr, this message translates to:
  /// **'Payé'**
  String get real_estate_rent_paid;

  /// No description provided for @real_estate_rent_periods_title.
  ///
  /// In fr, this message translates to:
  /// **'Loyers'**
  String get real_estate_rent_periods_title;

  /// No description provided for @real_estate_rent_unpaid.
  ///
  /// In fr, this message translates to:
  /// **'Impayé'**
  String get real_estate_rent_unpaid;

  /// No description provided for @real_estate_self_financed.
  ///
  /// In fr, this message translates to:
  /// **'Autofinancé'**
  String get real_estate_self_financed;

  /// No description provided for @real_estate_tenant_optional_label.
  ///
  /// In fr, this message translates to:
  /// **'Locataire (facultatif)'**
  String get real_estate_tenant_optional_label;

  /// No description provided for @real_estate_total_project_cost_label.
  ///
  /// In fr, this message translates to:
  /// **'Coût total du projet'**
  String get real_estate_total_project_cost_label;

  /// No description provided for @real_estate_work_category_electrical.
  ///
  /// In fr, this message translates to:
  /// **'Électricité'**
  String get real_estate_work_category_electrical;

  /// No description provided for @real_estate_work_category_furniture.
  ///
  /// In fr, this message translates to:
  /// **'Mobilier'**
  String get real_estate_work_category_furniture;

  /// No description provided for @real_estate_work_category_other.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get real_estate_work_category_other;

  /// No description provided for @real_estate_work_category_paint.
  ///
  /// In fr, this message translates to:
  /// **'Peinture'**
  String get real_estate_work_category_paint;

  /// No description provided for @real_estate_work_category_plumbing.
  ///
  /// In fr, this message translates to:
  /// **'Plomberie'**
  String get real_estate_work_category_plumbing;

  /// No description provided for @real_estate_work_category_structural.
  ///
  /// In fr, this message translates to:
  /// **'Gros œuvre'**
  String get real_estate_work_category_structural;

  /// No description provided for @real_estate_work_item_amount_label.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get real_estate_work_item_amount_label;

  /// No description provided for @real_estate_work_item_category_optional_label.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie (facultative)'**
  String get real_estate_work_item_category_optional_label;

  /// No description provided for @real_estate_work_item_label_field.
  ///
  /// In fr, this message translates to:
  /// **'Libellé'**
  String get real_estate_work_item_label_field;

  /// No description provided for @real_estate_work_item_label_hint.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Réfection toiture'**
  String get real_estate_work_item_label_hint;

  /// No description provided for @real_estate_work_items_included_note.
  ///
  /// In fr, this message translates to:
  /// **'Dont {amount} de travaux (onglet Travaux).'**
  String real_estate_work_items_included_note(String amount);

  /// No description provided for @real_estate_work_items_title.
  ///
  /// In fr, this message translates to:
  /// **'Travaux'**
  String get real_estate_work_items_title;

  /// No description provided for @real_estate_work_items_total_label.
  ///
  /// In fr, this message translates to:
  /// **'Total : {amount}'**
  String real_estate_work_items_total_label(String amount);

  /// No description provided for @search_category_enveloppe.
  ///
  /// In fr, this message translates to:
  /// **'Enveloppes'**
  String get search_category_enveloppe;

  /// No description provided for @search_category_fondamentaux.
  ///
  /// In fr, this message translates to:
  /// **'Fondamentaux'**
  String get search_category_fondamentaux;

  /// No description provided for @search_category_formation.
  ///
  /// In fr, this message translates to:
  /// **'Formation'**
  String get search_category_formation;

  /// No description provided for @search_category_page.
  ///
  /// In fr, this message translates to:
  /// **'Pages'**
  String get search_category_page;

  /// No description provided for @search_category_patrimoine.
  ///
  /// In fr, this message translates to:
  /// **'Patrimoine'**
  String get search_category_patrimoine;

  /// No description provided for @search_category_vocabulaire.
  ///
  /// In fr, this message translates to:
  /// **'Vocabulaire'**
  String get search_category_vocabulaire;

  /// No description provided for @search_no_results.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat'**
  String get search_no_results;

  /// No description provided for @search_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher dans Opime...'**
  String get search_placeholder;

  /// No description provided for @settings_encryption_confirm_password.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le mot de passe'**
  String get settings_encryption_confirm_password;

  /// No description provided for @settings_encryption_continue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get settings_encryption_continue;

  /// No description provided for @settings_encryption_dont_close_app.
  ///
  /// In fr, this message translates to:
  /// **'Ne ferme pas l\'application pendant cette opération (la fermeture de la fenêtre est bloquée le temps qu\'elle se termine).'**
  String get settings_encryption_dont_close_app;

  /// No description provided for @settings_encryption_enable_description.
  ///
  /// In fr, this message translates to:
  /// **'Choisis un mot de passe pour chiffrer les données privées de ce coffre-fort (comptes, budget, passifs, projets, notes de stratégie, simulations). Il te sera redemandé à chaque lancement de l\'app.'**
  String get settings_encryption_enable_description;

  /// No description provided for @settings_encryption_encrypting_progress_label.
  ///
  /// In fr, this message translates to:
  /// **'Chiffrement des données en cours...'**
  String get settings_encryption_encrypting_progress_label;

  /// No description provided for @settings_encryption_files_progress.
  ///
  /// In fr, this message translates to:
  /// **'{done} / {total} fichier(s)'**
  String settings_encryption_files_progress(int done, int total);

  /// No description provided for @settings_encryption_preparing.
  ///
  /// In fr, this message translates to:
  /// **'Préparation...'**
  String get settings_encryption_preparing;

  /// No description provided for @settings_encryption_recovery_key_confirmed_checkbox.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai noté cette clé en lieu sûr'**
  String get settings_encryption_recovery_key_confirmed_checkbox;

  /// No description provided for @settings_encryption_recovery_key_description.
  ///
  /// In fr, this message translates to:
  /// **'Note-la en lieu sûr (gestionnaire de mots de passe, papier...). Elle permet de redéfinir ton mot de passe si tu l\'oublies — sans elle, tes données sont définitivement perdues. Elle ne sera plus jamais affichée.'**
  String get settings_encryption_recovery_key_description;

  /// No description provided for @settings_encryption_recovery_key_title.
  ///
  /// In fr, this message translates to:
  /// **'Ta clé de récupération'**
  String get settings_encryption_recovery_key_title;

  /// No description provided for @settings_tax_abattement_conjoint_label.
  ///
  /// In fr, this message translates to:
  /// **'Conjoint/PACS (€)'**
  String get settings_tax_abattement_conjoint_label;

  /// No description provided for @settings_tax_abattement_enfant_label.
  ///
  /// In fr, this message translates to:
  /// **'Enfant (€)'**
  String get settings_tax_abattement_enfant_label;

  /// No description provided for @settings_tax_abattement_petit_enfant_label.
  ///
  /// In fr, this message translates to:
  /// **'Petit-enfant (€)'**
  String get settings_tax_abattement_petit_enfant_label;

  /// No description provided for @settings_tax_abattements_title.
  ///
  /// In fr, this message translates to:
  /// **'Abattements'**
  String get settings_tax_abattements_title;

  /// No description provided for @settings_tax_bareme_epoux_title.
  ///
  /// In fr, this message translates to:
  /// **'Barème entre époux ou partenaires de PACS'**
  String get settings_tax_bareme_epoux_title;

  /// No description provided for @settings_tax_bareme_ligne_directe_title.
  ///
  /// In fr, this message translates to:
  /// **'Barème en ligne directe (parent/enfant)'**
  String get settings_tax_bareme_ligne_directe_title;

  /// No description provided for @settings_tax_bracket_beyond.
  ///
  /// In fr, this message translates to:
  /// **'Au-delà'**
  String get settings_tax_bracket_beyond;

  /// No description provided for @settings_tax_bracket_nue_propriete_percent.
  ///
  /// In fr, this message translates to:
  /// **'Nue-propriété (%)'**
  String get settings_tax_bracket_nue_propriete_percent;

  /// No description provided for @settings_tax_bracket_rate_percent.
  ///
  /// In fr, this message translates to:
  /// **'Taux (%)'**
  String get settings_tax_bracket_rate_percent;

  /// No description provided for @settings_tax_bracket_upto_eur.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu\'à (€)'**
  String get settings_tax_bracket_upto_eur;

  /// No description provided for @settings_tax_bracket_upto_years.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu\'à (ans)'**
  String get settings_tax_bracket_upto_years;

  /// No description provided for @settings_tax_demembrement_description.
  ///
  /// In fr, this message translates to:
  /// **'Barème fiscal de l\'usufruit selon l\'âge de l\'usufruitier (article 669 CGI) — voir la page Simulation → Transmission, onglet Démembrement.'**
  String get settings_tax_demembrement_description;

  /// No description provided for @settings_tax_demembrement_title.
  ///
  /// In fr, this message translates to:
  /// **'Démembrement (usufruit / nue-propriété)'**
  String get settings_tax_demembrement_title;

  /// No description provided for @settings_tax_donation_description.
  ///
  /// In fr, this message translates to:
  /// **'Barèmes des droits de mutation à titre gratuit (article 777 CGI) et abattements par lien de parenté — voir la page Simulation → Transmission, onglets Démembrement/Donation/Succession.'**
  String get settings_tax_donation_description;

  /// No description provided for @settings_tax_donation_title.
  ///
  /// In fr, this message translates to:
  /// **'Donation et succession'**
  String get settings_tax_donation_title;

  /// No description provided for @settings_tax_ifi_description.
  ///
  /// In fr, this message translates to:
  /// **'Barème par tranches de patrimoine immobilier net (article 977 CGI) et seuil en-dessous duquel l\'IFI n\'est pas dû du tout.'**
  String get settings_tax_ifi_description;

  /// No description provided for @settings_tax_ifi_threshold_label.
  ///
  /// In fr, this message translates to:
  /// **'Seuil d\'imposition (€) — exonération totale en-dessous'**
  String get settings_tax_ifi_threshold_label;

  /// No description provided for @settings_tax_ifi_title.
  ///
  /// In fr, this message translates to:
  /// **'IFI (impôt sur la fortune immobilière)'**
  String get settings_tax_ifi_title;

  /// No description provided for @settings_tax_ir_description.
  ///
  /// In fr, this message translates to:
  /// **'Barème progressif par part de quotient familial (article 197 CGI) — voir la page Simulation → Fiscalité, onglet IR.'**
  String get settings_tax_ir_description;

  /// No description provided for @settings_tax_ir_title.
  ///
  /// In fr, this message translates to:
  /// **'Impôt sur le revenu'**
  String get settings_tax_ir_title;

  /// No description provided for @settings_tax_page_description.
  ///
  /// In fr, this message translates to:
  /// **'Barèmes, seuils et abattements utilisés par les simulateurs (impôt sur le revenu, IFI, démembrement, donation et succession). Modifie une valeur ici si l\'État la révise, sans attendre une mise à jour du logiciel — chacune peut être réinitialisée individuellement à sa référence légale connue via l\'icône ↺ qui apparaît à côté d\'une valeur modifiée.'**
  String get settings_tax_page_description;

  /// No description provided for @settings_tax_pfu_description.
  ///
  /// In fr, this message translates to:
  /// **'\"Flat tax\" sur les revenus de capitaux mobiliers et plus-values mobilières, décomposée en sa part IR et sa part prélèvements sociaux — l\'État peut réviser l\'une sans l\'autre (ex : PS passés de 15,5 % à 17,2 % en 2018, puis à 18,6 % début 2026, sans toucher au taux d\'IR). Valeurs de référence uniquement pour l\'instant : aucun simulateur de l\'app ne les utilise encore dans un calcul.'**
  String get settings_tax_pfu_description;

  /// No description provided for @settings_tax_pfu_ir_label.
  ///
  /// In fr, this message translates to:
  /// **'Part IR (%)'**
  String get settings_tax_pfu_ir_label;

  /// No description provided for @settings_tax_pfu_ps_label.
  ///
  /// In fr, this message translates to:
  /// **'Part prélèvements sociaux (%)'**
  String get settings_tax_pfu_ps_label;

  /// No description provided for @settings_tax_pfu_title.
  ///
  /// In fr, this message translates to:
  /// **'PFU (prélèvement forfaitaire unique)'**
  String get settings_tax_pfu_title;

  /// No description provided for @settings_tax_reset_to_legal_value.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser à la valeur légale'**
  String get settings_tax_reset_to_legal_value;

  /// No description provided for @simulations_loan_application_fees_label.
  ///
  /// In fr, this message translates to:
  /// **'Frais de dossier'**
  String get simulations_loan_application_fees_label;

  /// No description provided for @simulations_loan_capital_repaid_at_maturity.
  ///
  /// In fr, this message translates to:
  /// **'Capital remboursé en une fois à l\'échéance : {amount}'**
  String simulations_loan_capital_repaid_at_maturity(String amount);

  /// No description provided for @simulations_loan_chart_average_monthly_payment.
  ///
  /// In fr, this message translates to:
  /// **'mensualité moyenne'**
  String get simulations_loan_chart_average_monthly_payment;

  /// No description provided for @simulations_loan_chart_capital.
  ///
  /// In fr, this message translates to:
  /// **'Capital'**
  String get simulations_loan_chart_capital;

  /// No description provided for @simulations_loan_chart_insurance.
  ///
  /// In fr, this message translates to:
  /// **'Assurance'**
  String get simulations_loan_chart_insurance;

  /// No description provided for @simulations_loan_chart_interest.
  ///
  /// In fr, this message translates to:
  /// **'Intérêts'**
  String get simulations_loan_chart_interest;

  /// No description provided for @simulations_loan_chart_today.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get simulations_loan_chart_today;

  /// No description provided for @simulations_loan_chart_year_label.
  ///
  /// In fr, this message translates to:
  /// **'Année {year}'**
  String simulations_loan_chart_year_label(int year);

  /// No description provided for @simulations_loan_deferral_duration_label.
  ///
  /// In fr, this message translates to:
  /// **'Durée du différé'**
  String get simulations_loan_deferral_duration_label;

  /// No description provided for @simulations_loan_deferral_label.
  ///
  /// In fr, this message translates to:
  /// **'Différé de remboursement'**
  String get simulations_loan_deferral_label;

  /// No description provided for @simulations_loan_deferral_partial.
  ///
  /// In fr, this message translates to:
  /// **'Franchise partielle'**
  String get simulations_loan_deferral_partial;

  /// No description provided for @simulations_loan_deferral_partial_explanation.
  ///
  /// In fr, this message translates to:
  /// **'Seuls les intérêts sont payés pendant le différé, le capital ne bouge pas.'**
  String get simulations_loan_deferral_partial_explanation;

  /// No description provided for @simulations_loan_deferral_total.
  ///
  /// In fr, this message translates to:
  /// **'Franchise totale'**
  String get simulations_loan_deferral_total;

  /// No description provided for @simulations_loan_deferral_total_explanation.
  ///
  /// In fr, this message translates to:
  /// **'Aucun paiement pendant le différé, les intérêts s\'ajoutent au capital restant dû.'**
  String get simulations_loan_deferral_total_explanation;

  /// No description provided for @simulations_loan_derived_borrowed_amount.
  ///
  /// In fr, this message translates to:
  /// **'Montant emprunté (dérivé) : {amount}'**
  String simulations_loan_derived_borrowed_amount(String amount);

  /// No description provided for @simulations_loan_disclaimer.
  ///
  /// In fr, this message translates to:
  /// **'Simulation de prêt indicative : les résultats reposent sur des hypothèses simplifiées (taux constants, assurance linéaire, frais fixes). Les conditions bancaires réelles, garanties et clauses contractuelles peuvent modifier le coût total du crédit.'**
  String get simulations_loan_disclaimer;

  /// No description provided for @simulations_loan_down_payment_label.
  ///
  /// In fr, this message translates to:
  /// **'Apport'**
  String get simulations_loan_down_payment_label;

  /// No description provided for @simulations_loan_during_deferral_monthly_payment.
  ///
  /// In fr, this message translates to:
  /// **'Pendant le différé : {amount}/mois'**
  String simulations_loan_during_deferral_monthly_payment(String amount);

  /// No description provided for @simulations_loan_guarantee_fees_label.
  ///
  /// In fr, this message translates to:
  /// **'Frais de garantie'**
  String get simulations_loan_guarantee_fees_label;

  /// No description provided for @simulations_loan_including_insurance.
  ///
  /// In fr, this message translates to:
  /// **'Dont assurance'**
  String get simulations_loan_including_insurance;

  /// No description provided for @simulations_loan_interest_rate_label.
  ///
  /// In fr, this message translates to:
  /// **'Taux d\'intérêt'**
  String get simulations_loan_interest_rate_label;

  /// No description provided for @simulations_loan_monthly_insurance_label.
  ///
  /// In fr, this message translates to:
  /// **'Assurance mensuelle'**
  String get simulations_loan_monthly_insurance_label;

  /// No description provided for @simulations_loan_monthly_payments_label.
  ///
  /// In fr, this message translates to:
  /// **'Mensualités'**
  String get simulations_loan_monthly_payments_label;

  /// No description provided for @simulations_loan_per_month_suffix.
  ///
  /// In fr, this message translates to:
  /// **'mois'**
  String get simulations_loan_per_month_suffix;

  /// No description provided for @simulations_loan_project_amount_label.
  ///
  /// In fr, this message translates to:
  /// **'Montant du projet'**
  String get simulations_loan_project_amount_label;

  /// No description provided for @simulations_loan_repayment_duration_label.
  ///
  /// In fr, this message translates to:
  /// **'Durée de remboursement'**
  String get simulations_loan_repayment_duration_label;

  /// No description provided for @simulations_loan_reset_parameters.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser les paramètres'**
  String get simulations_loan_reset_parameters;

  /// No description provided for @simulations_loan_suffix_eur_per_month.
  ///
  /// In fr, this message translates to:
  /// **'€/mois'**
  String get simulations_loan_suffix_eur_per_month;

  /// No description provided for @simulations_loan_suffix_months.
  ///
  /// In fr, this message translates to:
  /// **'mois'**
  String get simulations_loan_suffix_months;

  /// No description provided for @simulations_loan_suffix_years.
  ///
  /// In fr, this message translates to:
  /// **'ans'**
  String get simulations_loan_suffix_years;

  /// No description provided for @simulations_loan_summary_monthly_payment_is.
  ///
  /// In fr, this message translates to:
  /// **', votre mensualité s\'élève à '**
  String get simulations_loan_summary_monthly_payment_is;

  /// No description provided for @simulations_loan_summary_over.
  ///
  /// In fr, this message translates to:
  /// **' sur '**
  String get simulations_loan_summary_over;

  /// No description provided for @simulations_loan_summary_prefix.
  ///
  /// In fr, this message translates to:
  /// **'Pour un emprunt de '**
  String get simulations_loan_summary_prefix;

  /// No description provided for @simulations_loan_total_cost_incl_fees_label.
  ///
  /// In fr, this message translates to:
  /// **'Coût total (frais inclus)'**
  String get simulations_loan_total_cost_incl_fees_label;

  /// No description provided for @simulations_loan_total_credit_cost_label.
  ///
  /// In fr, this message translates to:
  /// **'Coût total du crédit'**
  String get simulations_loan_total_credit_cost_label;

  /// No description provided for @simulations_loan_type_amortizing.
  ///
  /// In fr, this message translates to:
  /// **'Amortissable'**
  String get simulations_loan_type_amortizing;

  /// No description provided for @simulations_loan_type_infine.
  ///
  /// In fr, this message translates to:
  /// **'In fine'**
  String get simulations_loan_type_infine;

  /// No description provided for @simulations_loan_type_label.
  ///
  /// In fr, this message translates to:
  /// **'Type de crédit'**
  String get simulations_loan_type_label;

  /// No description provided for @simulations_real_estate_tab_estimation.
  ///
  /// In fr, this message translates to:
  /// **'Estimation'**
  String get simulations_real_estate_tab_estimation;

  /// No description provided for @simulations_real_estate_tab_loan.
  ///
  /// In fr, this message translates to:
  /// **'Prêt'**
  String get simulations_real_estate_tab_loan;

  /// No description provided for @simulations_real_estate_tab_scoring.
  ///
  /// In fr, this message translates to:
  /// **'Scoring'**
  String get simulations_real_estate_tab_scoring;

  /// No description provided for @simulations_scoring_age_label.
  ///
  /// In fr, this message translates to:
  /// **'Âge'**
  String get simulations_scoring_age_label;

  /// No description provided for @simulations_scoring_bank_history_label.
  ///
  /// In fr, this message translates to:
  /// **'Historique bancaire'**
  String get simulations_scoring_bank_history_label;

  /// No description provided for @simulations_scoring_bank_history_none_1y.
  ///
  /// In fr, this message translates to:
  /// **'Aucun incident (< 1 an)'**
  String get simulations_scoring_bank_history_none_1y;

  /// No description provided for @simulations_scoring_bank_history_none_3y.
  ///
  /// In fr, this message translates to:
  /// **'Aucun incident (≥ 3 ans)'**
  String get simulations_scoring_bank_history_none_3y;

  /// No description provided for @simulations_scoring_bank_history_none_6m.
  ///
  /// In fr, this message translates to:
  /// **'Aucun incident (< 6 mois)'**
  String get simulations_scoring_bank_history_none_6m;

  /// No description provided for @simulations_scoring_bank_history_one_6m.
  ///
  /// In fr, this message translates to:
  /// **'1 incident (< 6 mois)'**
  String get simulations_scoring_bank_history_one_6m;

  /// No description provided for @simulations_scoring_bank_history_several_6m.
  ///
  /// In fr, this message translates to:
  /// **'Plusieurs incidents (< 6 mois)'**
  String get simulations_scoring_bank_history_several_6m;

  /// No description provided for @simulations_scoring_debt_ratio_label.
  ///
  /// In fr, this message translates to:
  /// **'Taux d\'endettement'**
  String get simulations_scoring_debt_ratio_label;

  /// No description provided for @simulations_scoring_disclaimer.
  ///
  /// In fr, this message translates to:
  /// **'Estimation pédagogique et indicative : la grille de notation utilisée ici est une simplification courante des critères bancaires classiques, pas le barème d\'un établissement précis. Le scoring réel d\'une banque tient compte de bien d\'autres éléments (garanties, patrimoine, politique interne du moment...).'**
  String get simulations_scoring_disclaimer;

  /// No description provided for @simulations_scoring_disposable_income_label.
  ///
  /// In fr, this message translates to:
  /// **'Revenu disponible'**
  String get simulations_scoring_disposable_income_label;

  /// No description provided for @simulations_scoring_disposable_income_value.
  ///
  /// In fr, this message translates to:
  /// **'{value} € / an'**
  String simulations_scoring_disposable_income_value(int value);

  /// No description provided for @simulations_scoring_duration_years_fractional.
  ///
  /// In fr, this message translates to:
  /// **'{years} ans'**
  String simulations_scoring_duration_years_fractional(String years);

  /// No description provided for @simulations_scoring_household_monthly_income_label.
  ///
  /// In fr, this message translates to:
  /// **'Revenus mensuels du foyer'**
  String get simulations_scoring_household_monthly_income_label;

  /// No description provided for @simulations_scoring_income_charges_section_label.
  ///
  /// In fr, this message translates to:
  /// **'Revenus & charges'**
  String get simulations_scoring_income_charges_section_label;

  /// No description provided for @simulations_scoring_income_seniority_label.
  ///
  /// In fr, this message translates to:
  /// **'Ancienneté des revenus actuels'**
  String get simulations_scoring_income_seniority_label;

  /// No description provided for @simulations_scoring_income_stability_label.
  ///
  /// In fr, this message translates to:
  /// **'Stabilité des revenus'**
  String get simulations_scoring_income_stability_label;

  /// No description provided for @simulations_scoring_monthly_expenses_label.
  ///
  /// In fr, this message translates to:
  /// **'Charges mensuelles (hors prêt immo)'**
  String get simulations_scoring_monthly_expenses_label;

  /// No description provided for @simulations_scoring_monthly_savings_label.
  ///
  /// In fr, this message translates to:
  /// **'Épargne mensuelle'**
  String get simulations_scoring_monthly_savings_label;

  /// No description provided for @simulations_scoring_mortgage_payment_label.
  ///
  /// In fr, this message translates to:
  /// **'Mensualité du prêt immobilier'**
  String get simulations_scoring_mortgage_payment_label;

  /// No description provided for @simulations_scoring_overall_profile_label.
  ///
  /// In fr, this message translates to:
  /// **'Profil {tier}'**
  String simulations_scoring_overall_profile_label(String tier);

  /// No description provided for @simulations_scoring_prefilled_from_loan_tab.
  ///
  /// In fr, this message translates to:
  /// **'Pré-remplie depuis l\'onglet Prêt tant que non modifiée ici.'**
  String get simulations_scoring_prefilled_from_loan_tab;

  /// No description provided for @simulations_scoring_profession_employee.
  ///
  /// In fr, this message translates to:
  /// **'Salarié'**
  String get simulations_scoring_profession_employee;

  /// No description provided for @simulations_scoring_profession_executive.
  ///
  /// In fr, this message translates to:
  /// **'Cadre'**
  String get simulations_scoring_profession_executive;

  /// No description provided for @simulations_scoring_profession_executive_senior.
  ///
  /// In fr, this message translates to:
  /// **'Dirigeant / Cadre supérieur'**
  String get simulations_scoring_profession_executive_senior;

  /// No description provided for @simulations_scoring_profession_label.
  ///
  /// In fr, this message translates to:
  /// **'Profession'**
  String get simulations_scoring_profession_label;

  /// No description provided for @simulations_scoring_profession_unemployed.
  ///
  /// In fr, this message translates to:
  /// **'Chômeur'**
  String get simulations_scoring_profession_unemployed;

  /// No description provided for @simulations_scoring_profession_worker.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrier'**
  String get simulations_scoring_profession_worker;

  /// No description provided for @simulations_scoring_profile_section_label.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get simulations_scoring_profile_section_label;

  /// No description provided for @simulations_scoring_savings_effort_label.
  ///
  /// In fr, this message translates to:
  /// **'Effort d\'épargne'**
  String get simulations_scoring_savings_effort_label;

  /// No description provided for @simulations_scoring_suffix_shares.
  ///
  /// In fr, this message translates to:
  /// **'parts'**
  String get simulations_scoring_suffix_shares;

  /// No description provided for @simulations_scoring_tax_shares_label.
  ///
  /// In fr, this message translates to:
  /// **'Parts fiscales'**
  String get simulations_scoring_tax_shares_label;

  /// No description provided for @simulations_scoring_tier_average.
  ///
  /// In fr, this message translates to:
  /// **'Moyen'**
  String get simulations_scoring_tier_average;

  /// No description provided for @simulations_scoring_tier_critical.
  ///
  /// In fr, this message translates to:
  /// **'Critique'**
  String get simulations_scoring_tier_critical;

  /// No description provided for @simulations_scoring_tier_excellent.
  ///
  /// In fr, this message translates to:
  /// **'Excellent'**
  String get simulations_scoring_tier_excellent;

  /// No description provided for @simulations_scoring_tier_good.
  ///
  /// In fr, this message translates to:
  /// **'Bon'**
  String get simulations_scoring_tier_good;

  /// No description provided for @simulations_scoring_tier_poor.
  ///
  /// In fr, this message translates to:
  /// **'Mauvais'**
  String get simulations_scoring_tier_poor;

  /// No description provided for @simulations_scoring_total_points.
  ///
  /// In fr, this message translates to:
  /// **'{points} / 35 points'**
  String simulations_scoring_total_points(int points);

  /// No description provided for @transactions_export_deselect_all.
  ///
  /// In fr, this message translates to:
  /// **'Tout désélectionner'**
  String get transactions_export_deselect_all;

  /// No description provided for @transactions_export_empty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune transaction à exporter pour l\'instant.'**
  String get transactions_export_empty;

  /// No description provided for @transactions_export_failed_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier n\'a pas pu être généré ou enregistré : {error}'**
  String transactions_export_failed_subtitle(String error);

  /// No description provided for @transactions_export_failed_title.
  ///
  /// In fr, this message translates to:
  /// **'Échec de l\'export'**
  String get transactions_export_failed_title;

  /// No description provided for @transactions_export_save_dialog_title.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer les transactions'**
  String get transactions_export_save_dialog_title;

  /// No description provided for @transactions_export_select_all.
  ///
  /// In fr, this message translates to:
  /// **'Tout sélectionner'**
  String get transactions_export_select_all;

  /// No description provided for @transactions_export_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez les comptes à inclure.'**
  String get transactions_export_subtitle;

  /// No description provided for @transactions_export_success_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier a été enregistré : {path}'**
  String transactions_export_success_subtitle(String path);

  /// No description provided for @transactions_export_success_title.
  ///
  /// In fr, this message translates to:
  /// **'Export réussi'**
  String get transactions_export_success_title;

  /// No description provided for @transactions_export_title.
  ///
  /// In fr, this message translates to:
  /// **'Exporter mes transactions'**
  String get transactions_export_title;

  /// No description provided for @transactions_export_transaction_count.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 transaction} other{{count} transactions}}'**
  String transactions_export_transaction_count(int count);

  /// No description provided for @updates_banner_new_version.
  ///
  /// In fr, this message translates to:
  /// **'Une nouvelle version d\'Opime est disponible ({version}).'**
  String updates_banner_new_version(String version);

  /// No description provided for @nav_assets_actions_funds.
  ///
  /// In fr, this message translates to:
  /// **'Actions & Fonds'**
  String get nav_assets_actions_funds;

  /// No description provided for @nav_assets_private_equity.
  ///
  /// In fr, this message translates to:
  /// **'Private Equity'**
  String get nav_assets_private_equity;

  /// No description provided for @nav_assets_real_estate.
  ///
  /// In fr, this message translates to:
  /// **'Immobilier'**
  String get nav_assets_real_estate;

  /// No description provided for @nav_assets_crypto.
  ///
  /// In fr, this message translates to:
  /// **'Crypto'**
  String get nav_assets_crypto;

  /// No description provided for @nav_assets_precious_metals.
  ///
  /// In fr, this message translates to:
  /// **'Métaux précieux'**
  String get nav_assets_precious_metals;

  /// No description provided for @nav_assets_savings.
  ///
  /// In fr, this message translates to:
  /// **'Épargne'**
  String get nav_assets_savings;

  /// No description provided for @nav_assets_other.
  ///
  /// In fr, this message translates to:
  /// **'Autres'**
  String get nav_assets_other;

  /// No description provided for @nav_liabilities_loans.
  ///
  /// In fr, this message translates to:
  /// **'Emprunts'**
  String get nav_liabilities_loans;

  /// No description provided for @nav_liabilities_mortgages.
  ///
  /// In fr, this message translates to:
  /// **'Crédits immobiliers'**
  String get nav_liabilities_mortgages;

  /// No description provided for @nav_investment.
  ///
  /// In fr, this message translates to:
  /// **'Fondamentaux'**
  String get nav_investment;

  /// No description provided for @nav_invest_why.
  ///
  /// In fr, this message translates to:
  /// **'Pourquoi investir ?'**
  String get nav_invest_why;

  /// No description provided for @nav_invest_inflation.
  ///
  /// In fr, this message translates to:
  /// **'L\'inflation'**
  String get nav_invest_inflation;

  /// No description provided for @nav_invest_risk.
  ///
  /// In fr, this message translates to:
  /// **'Le risque'**
  String get nav_invest_risk;

  /// No description provided for @nav_invest_diversification.
  ///
  /// In fr, this message translates to:
  /// **'Diversification'**
  String get nav_invest_diversification;

  /// No description provided for @nav_invest_etf.
  ///
  /// In fr, this message translates to:
  /// **'Les ETF'**
  String get nav_invest_etf;

  /// No description provided for @nav_invest_fees.
  ///
  /// In fr, this message translates to:
  /// **'Les frais'**
  String get nav_invest_fees;

  /// No description provided for @nav_invest_taxation.
  ///
  /// In fr, this message translates to:
  /// **'La fiscalité'**
  String get nav_invest_taxation;

  /// No description provided for @nav_invest_pyramid.
  ///
  /// In fr, this message translates to:
  /// **'Pyramide de l\'investissement'**
  String get nav_invest_pyramid;

  /// No description provided for @nav_invest_allocation.
  ///
  /// In fr, this message translates to:
  /// **'Allocation stratégique/dynamique'**
  String get nav_invest_allocation;

  /// No description provided for @nav_invest_long_term.
  ///
  /// In fr, this message translates to:
  /// **'Le temps long'**
  String get nav_invest_long_term;

  /// No description provided for @nav_envelopes.
  ///
  /// In fr, this message translates to:
  /// **'Enveloppes'**
  String get nav_envelopes;

  /// No description provided for @nav_envelope_current_account.
  ///
  /// In fr, this message translates to:
  /// **'Compte courant'**
  String get nav_envelope_current_account;

  /// No description provided for @nav_envelope_livret_a.
  ///
  /// In fr, this message translates to:
  /// **'Livret A'**
  String get nav_envelope_livret_a;

  /// No description provided for @nav_envelope_ldds.
  ///
  /// In fr, this message translates to:
  /// **'LDDS'**
  String get nav_envelope_ldds;

  /// No description provided for @nav_envelope_lep.
  ///
  /// In fr, this message translates to:
  /// **'LEP'**
  String get nav_envelope_lep;

  /// No description provided for @nav_envelope_pel.
  ///
  /// In fr, this message translates to:
  /// **'PEL'**
  String get nav_envelope_pel;

  /// No description provided for @nav_envelope_cto.
  ///
  /// In fr, this message translates to:
  /// **'CTO'**
  String get nav_envelope_cto;

  /// No description provided for @nav_envelope_pea.
  ///
  /// In fr, this message translates to:
  /// **'PEA'**
  String get nav_envelope_pea;

  /// No description provided for @nav_envelope_life_insurance.
  ///
  /// In fr, this message translates to:
  /// **'Assurance-vie'**
  String get nav_envelope_life_insurance;

  /// No description provided for @nav_envelope_capitalization_contract.
  ///
  /// In fr, this message translates to:
  /// **'Contrat de capitalisation'**
  String get nav_envelope_capitalization_contract;

  /// No description provided for @nav_envelope_pee_peg.
  ///
  /// In fr, this message translates to:
  /// **'PEE / PEG'**
  String get nav_envelope_pee_peg;

  /// No description provided for @nav_envelope_per.
  ///
  /// In fr, this message translates to:
  /// **'PER'**
  String get nav_envelope_per;

  /// No description provided for @nav_training.
  ///
  /// In fr, this message translates to:
  /// **'Formation'**
  String get nav_training;

  /// No description provided for @nav_training_stock_market.
  ///
  /// In fr, this message translates to:
  /// **'Bourse'**
  String get nav_training_stock_market;

  /// No description provided for @nav_training_precious_metals.
  ///
  /// In fr, this message translates to:
  /// **'Métaux précieux'**
  String get nav_training_precious_metals;

  /// No description provided for @nav_training_crypto.
  ///
  /// In fr, this message translates to:
  /// **'Crypto'**
  String get nav_training_crypto;

  /// No description provided for @nav_training_real_estate.
  ///
  /// In fr, this message translates to:
  /// **'Immobilier'**
  String get nav_training_real_estate;

  /// No description provided for @nav_training_wealth_structuring.
  ///
  /// In fr, this message translates to:
  /// **'Structuration patrimoniale'**
  String get nav_training_wealth_structuring;

  /// No description provided for @simulations_wealth_tab_compound_interest.
  ///
  /// In fr, this message translates to:
  /// **'Intérêts composés'**
  String get simulations_wealth_tab_compound_interest;

  /// No description provided for @simulations_wealth_tab_deterministic_compound_interest.
  ///
  /// In fr, this message translates to:
  /// **'Déterministe (Intérêts composés)'**
  String get simulations_wealth_tab_deterministic_compound_interest;

  /// No description provided for @simulations_wealth_tab_monte_carlo.
  ///
  /// In fr, this message translates to:
  /// **'Monte-Carlo'**
  String get simulations_wealth_tab_monte_carlo;

  /// No description provided for @simulations_wealth_tab_stochastic_monte_carlo.
  ///
  /// In fr, this message translates to:
  /// **'Stochastique (Monte-Carlo)'**
  String get simulations_wealth_tab_stochastic_monte_carlo;

  /// No description provided for @simulations_wealth_simple_disclaimer.
  ///
  /// In fr, this message translates to:
  /// **'Projection déterministe indicative fondée sur des rendements constants et une fiscalité simplifiée. Les valeurs « pouvoir d\'achat actuel » actualisent le résultat nominal avec le taux d\'inflation renseigné (valeur réelle = valeur nominale ÷ (1 + inflation)^années). Les marchés, frais, impôts réels et aléas de vie peuvent modifier significativement les résultats.'**
  String get simulations_wealth_simple_disclaimer;

  /// No description provided for @simulations_wealth_monte_carlo_disclaimer.
  ///
  /// In fr, this message translates to:
  /// **'Simulation Monte-Carlo indicative: les distributions retenues et hypothèses de volatilité restent simplifiées. Les percentiles ne constituent ni une garantie de performance ni une recommandation d\'investissement.'**
  String get simulations_wealth_monte_carlo_disclaimer;

  /// No description provided for @simulations_wealth_current_assets.
  ///
  /// In fr, this message translates to:
  /// **'Patrimoine actuel'**
  String get simulations_wealth_current_assets;

  /// No description provided for @simulations_wealth_initial_asset_allocation.
  ///
  /// In fr, this message translates to:
  /// **'Répartition de votre patrimoine initial'**
  String get simulations_wealth_initial_asset_allocation;

  /// No description provided for @simulations_wealth_stock.
  ///
  /// In fr, this message translates to:
  /// **'Bourse'**
  String get simulations_wealth_stock;

  /// No description provided for @simulations_wealth_other.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get simulations_wealth_other;

  /// No description provided for @simulations_wealth_monthly_investments.
  ///
  /// In fr, this message translates to:
  /// **'Investissements mensuels'**
  String get simulations_wealth_monthly_investments;

  /// No description provided for @simulations_wealth_investment_allocation.
  ///
  /// In fr, this message translates to:
  /// **'Répartition des investissements'**
  String get simulations_wealth_investment_allocation;

  /// No description provided for @simulations_wealth_savings_years.
  ///
  /// In fr, this message translates to:
  /// **'Nombre d\'années d\'épargne'**
  String get simulations_wealth_savings_years;

  /// No description provided for @simulations_wealth_stock_return.
  ///
  /// In fr, this message translates to:
  /// **'Rendement bourse'**
  String get simulations_wealth_stock_return;

  /// No description provided for @simulations_wealth_other_return.
  ///
  /// In fr, this message translates to:
  /// **'Rendement autre'**
  String get simulations_wealth_other_return;

  /// No description provided for @simulations_wealth_stock_tax.
  ///
  /// In fr, this message translates to:
  /// **'Imposition bourse'**
  String get simulations_wealth_stock_tax;

  /// No description provided for @simulations_wealth_other_tax.
  ///
  /// In fr, this message translates to:
  /// **'Imposition autre'**
  String get simulations_wealth_other_tax;

  /// No description provided for @simulations_wealth_withdrawal_rate.
  ///
  /// In fr, this message translates to:
  /// **'Taux de retrait'**
  String get simulations_wealth_withdrawal_rate;

  /// No description provided for @simulations_wealth_inflation_rate.
  ///
  /// In fr, this message translates to:
  /// **'Taux d\'inflation'**
  String get simulations_wealth_inflation_rate;

  /// No description provided for @simulations_wealth_reset_parameters.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser les paramètres'**
  String get simulations_wealth_reset_parameters;

  /// No description provided for @simulations_wealth_net_value_in_n_years.
  ///
  /// In fr, this message translates to:
  /// **'Valeur nette dans {count} ans'**
  String simulations_wealth_net_value_in_n_years(int count);

  /// No description provided for @simulations_wealth_passive_income_prefix.
  ///
  /// In fr, this message translates to:
  /// **'soit un revenu passif d\'environ '**
  String get simulations_wealth_passive_income_prefix;

  /// No description provided for @simulations_wealth_initial_assets.
  ///
  /// In fr, this message translates to:
  /// **'Patrimoine initial'**
  String get simulations_wealth_initial_assets;

  /// No description provided for @simulations_wealth_contributions.
  ///
  /// In fr, this message translates to:
  /// **'Versements'**
  String get simulations_wealth_contributions;

  /// No description provided for @simulations_wealth_net_interest.
  ///
  /// In fr, this message translates to:
  /// **'Intérêts nets'**
  String get simulations_wealth_net_interest;

  /// No description provided for @simulations_wealth_stat_future_value.
  ///
  /// In fr, this message translates to:
  /// **'Valeur future'**
  String get simulations_wealth_stat_future_value;

  /// No description provided for @simulations_wealth_stat_included_capital_gains.
  ///
  /// In fr, this message translates to:
  /// **'Dont plus-value'**
  String get simulations_wealth_stat_included_capital_gains;

  /// No description provided for @simulations_wealth_stat_net_value.
  ///
  /// In fr, this message translates to:
  /// **'Valeur nette'**
  String get simulations_wealth_stat_net_value;

  /// No description provided for @simulations_wealth_stat_monthly_income.
  ///
  /// In fr, this message translates to:
  /// **'Revenu mensuel'**
  String get simulations_wealth_stat_monthly_income;

  /// No description provided for @simulations_wealth_stat_net_value_purchasing_power.
  ///
  /// In fr, this message translates to:
  /// **'Valeur nette (pouvoir d\'achat actuel)'**
  String get simulations_wealth_stat_net_value_purchasing_power;

  /// No description provided for @simulations_wealth_stat_monthly_income_purchasing_power.
  ///
  /// In fr, this message translates to:
  /// **'Revenu mensuel (pouvoir d\'achat actuel)'**
  String get simulations_wealth_stat_monthly_income_purchasing_power;

  /// No description provided for @simulations_wealth_chart_today.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get simulations_wealth_chart_today;

  /// No description provided for @simulations_wealth_chart_in_n_years.
  ///
  /// In fr, this message translates to:
  /// **'Dans {count} ans'**
  String simulations_wealth_chart_in_n_years(int count);

  /// No description provided for @simulations_wealth_chart_n_years.
  ///
  /// In fr, this message translates to:
  /// **'{count} ans'**
  String simulations_wealth_chart_n_years(int count);

  /// No description provided for @simulations_wealth_avg_stock_return.
  ///
  /// In fr, this message translates to:
  /// **'Rendement moyen bourse'**
  String get simulations_wealth_avg_stock_return;

  /// No description provided for @simulations_wealth_stock_std_dev.
  ///
  /// In fr, this message translates to:
  /// **'Écart-type bourse'**
  String get simulations_wealth_stock_std_dev;

  /// No description provided for @simulations_wealth_avg_other_return.
  ///
  /// In fr, this message translates to:
  /// **'Rendement moyen autre'**
  String get simulations_wealth_avg_other_return;

  /// No description provided for @simulations_wealth_other_std_dev.
  ///
  /// In fr, this message translates to:
  /// **'Écart-type autre'**
  String get simulations_wealth_other_std_dev;

  /// No description provided for @simulations_wealth_number_of_simulations.
  ///
  /// In fr, this message translates to:
  /// **'Nombre de simulations'**
  String get simulations_wealth_number_of_simulations;

  /// No description provided for @simulations_wealth_median_net_value_in_n_years.
  ///
  /// In fr, this message translates to:
  /// **'Valeur nette médiane dans {count} ans'**
  String simulations_wealth_median_net_value_in_n_years(int count);

  /// No description provided for @simulations_wealth_median_passive_income_prefix.
  ///
  /// In fr, this message translates to:
  /// **'soit un revenu passif médian d\'environ '**
  String get simulations_wealth_median_passive_income_prefix;

  /// No description provided for @simulations_wealth_between_p10_and_p90.
  ///
  /// In fr, this message translates to:
  /// **'Entre {p10} et {p90} selon les scénarios (10e-90e percentile)'**
  String simulations_wealth_between_p10_and_p90(String p10, String p90);

  /// No description provided for @simulations_wealth_median_net_interest.
  ///
  /// In fr, this message translates to:
  /// **'Médiane (intérêts nets)'**
  String get simulations_wealth_median_net_interest;

  /// No description provided for @simulations_wealth_stat_median_future_value.
  ///
  /// In fr, this message translates to:
  /// **'Valeur future médiane'**
  String get simulations_wealth_stat_median_future_value;

  /// No description provided for @simulations_wealth_stat_median_included_capital_gains.
  ///
  /// In fr, this message translates to:
  /// **'Dont plus-value médiane'**
  String get simulations_wealth_stat_median_included_capital_gains;

  /// No description provided for @simulations_wealth_stat_median_net_value.
  ///
  /// In fr, this message translates to:
  /// **'Valeur nette médiane'**
  String get simulations_wealth_stat_median_net_value;

  /// No description provided for @simulations_wealth_stat_median_monthly_income.
  ///
  /// In fr, this message translates to:
  /// **'Revenu mensuel médian'**
  String get simulations_wealth_stat_median_monthly_income;

  /// No description provided for @simulations_wealth_median_label.
  ///
  /// In fr, this message translates to:
  /// **'Médiane'**
  String get simulations_wealth_median_label;

  /// No description provided for @simulations_wealth_90th_percentile.
  ///
  /// In fr, this message translates to:
  /// **'90e percentile'**
  String get simulations_wealth_90th_percentile;

  /// No description provided for @simulations_wealth_10th_percentile.
  ///
  /// In fr, this message translates to:
  /// **'10e percentile'**
  String get simulations_wealth_10th_percentile;

  /// No description provided for @simulations_transmission_demembrement.
  ///
  /// In fr, this message translates to:
  /// **'Démembrement'**
  String get simulations_transmission_demembrement;

  /// No description provided for @simulations_transmission_donation.
  ///
  /// In fr, this message translates to:
  /// **'Donation'**
  String get simulations_transmission_donation;

  /// No description provided for @simulations_transmission_heritage.
  ///
  /// In fr, this message translates to:
  /// **'Héritage'**
  String get simulations_transmission_heritage;

  /// No description provided for @simulations_transmission_value_full_property.
  ///
  /// In fr, this message translates to:
  /// **'Valeur en pleine propriété'**
  String get simulations_transmission_value_full_property;

  /// No description provided for @simulations_transmission_usufruitier_age.
  ///
  /// In fr, this message translates to:
  /// **'Âge de l\'usufruitier'**
  String get simulations_transmission_usufruitier_age;

  /// No description provided for @simulations_transmission_number_beneficiary_children.
  ///
  /// In fr, this message translates to:
  /// **'Nombre d\'enfants bénéficiaires'**
  String get simulations_transmission_number_beneficiary_children;

  /// No description provided for @simulations_transmission_abatement_per_child_remaining.
  ///
  /// In fr, this message translates to:
  /// **'Abattement par enfant (restant)'**
  String get simulations_transmission_abatement_per_child_remaining;

  /// No description provided for @simulations_transmission_reset_parameters.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser les paramètres'**
  String get simulations_transmission_reset_parameters;

  /// No description provided for @simulations_transmission_projection_demembrement.
  ///
  /// In fr, this message translates to:
  /// **'Projection des droits en démembrement'**
  String get simulations_transmission_projection_demembrement;

  /// No description provided for @simulations_transmission_hypothesis_2026_nue.
  ///
  /// In fr, this message translates to:
  /// **'Hypothèse 2026 : nue-propriété '**
  String get simulations_transmission_hypothesis_2026_nue;

  /// No description provided for @simulations_transmission_usufruit_separator.
  ///
  /// In fr, this message translates to:
  /// **' / usufruit '**
  String get simulations_transmission_usufruit_separator;

  /// No description provided for @simulations_transmission_scenario_comparison.
  ///
  /// In fr, this message translates to:
  /// **'Comparaison des scénarios'**
  String get simulations_transmission_scenario_comparison;

  /// No description provided for @simulations_transmission_full_property_rights.
  ///
  /// In fr, this message translates to:
  /// **'Droits pleine propriété'**
  String get simulations_transmission_full_property_rights;

  /// No description provided for @simulations_transmission_demembrement_rights.
  ///
  /// In fr, this message translates to:
  /// **'Droits démembrement'**
  String get simulations_transmission_demembrement_rights;

  /// No description provided for @simulations_transmission_potential_savings.
  ///
  /// In fr, this message translates to:
  /// **'Économie potentielle'**
  String get simulations_transmission_potential_savings;

  /// No description provided for @simulations_transmission_np_value.
  ///
  /// In fr, this message translates to:
  /// **'Valeur NP'**
  String get simulations_transmission_np_value;

  /// No description provided for @simulations_transmission_np_taxable_per_child.
  ///
  /// In fr, this message translates to:
  /// **'Taxable NP / enfant'**
  String get simulations_transmission_np_taxable_per_child;

  /// No description provided for @simulations_transmission_np_rights_per_child.
  ///
  /// In fr, this message translates to:
  /// **'Droits NP / enfant'**
  String get simulations_transmission_np_rights_per_child;

  /// No description provided for @simulations_transmission_full_property_rights_if.
  ///
  /// In fr, this message translates to:
  /// **'Droits si pleine propriété'**
  String get simulations_transmission_full_property_rights_if;

  /// No description provided for @simulations_transmission_demembrement_rights_detail.
  ///
  /// In fr, this message translates to:
  /// **'Droits en démembrement'**
  String get simulations_transmission_demembrement_rights_detail;

  /// No description provided for @simulations_transmission_donation_amount.
  ///
  /// In fr, this message translates to:
  /// **'Montant de la donation'**
  String get simulations_transmission_donation_amount;

  /// No description provided for @simulations_transmission_number_beneficiaries.
  ///
  /// In fr, this message translates to:
  /// **'Nombre de bénéficiaires'**
  String get simulations_transmission_number_beneficiaries;

  /// No description provided for @simulations_transmission_donor_donee_link.
  ///
  /// In fr, this message translates to:
  /// **'Lien donateur / donataire'**
  String get simulations_transmission_donor_donee_link;

  /// No description provided for @simulations_transmission_child.
  ///
  /// In fr, this message translates to:
  /// **'Enfant'**
  String get simulations_transmission_child;

  /// No description provided for @simulations_transmission_grandchild.
  ///
  /// In fr, this message translates to:
  /// **'Petit-enfant'**
  String get simulations_transmission_grandchild;

  /// No description provided for @simulations_transmission_spouse_pacs.
  ///
  /// In fr, this message translates to:
  /// **'Conjoint/PACS'**
  String get simulations_transmission_spouse_pacs;

  /// No description provided for @simulations_transmission_abatement_per_beneficiary.
  ///
  /// In fr, this message translates to:
  /// **'Abattement pris en compte : {amount} / bénéficiaire'**
  String simulations_transmission_abatement_per_beneficiary(String amount);

  /// No description provided for @simulations_transmission_estimated_donation_rights.
  ///
  /// In fr, this message translates to:
  /// **'Droits de donation estimés'**
  String get simulations_transmission_estimated_donation_rights;

  /// No description provided for @simulations_transmission_effective_rate_prefix.
  ///
  /// In fr, this message translates to:
  /// **'Taux effectif '**
  String get simulations_transmission_effective_rate_prefix;

  /// No description provided for @simulations_transmission_effective_rate_suffix.
  ///
  /// In fr, this message translates to:
  /// **' sur le montant transmis.'**
  String get simulations_transmission_effective_rate_suffix;

  /// No description provided for @simulations_transmission_tax_breakdown.
  ///
  /// In fr, this message translates to:
  /// **'Répartition fiscale'**
  String get simulations_transmission_tax_breakdown;

  /// No description provided for @simulations_transmission_total_amount_transferred.
  ///
  /// In fr, this message translates to:
  /// **'Montant total transmis'**
  String get simulations_transmission_total_amount_transferred;

  /// No description provided for @simulations_transmission_total_taxable_base.
  ///
  /// In fr, this message translates to:
  /// **'Base taxable totale'**
  String get simulations_transmission_total_taxable_base;

  /// No description provided for @simulations_transmission_total_rights.
  ///
  /// In fr, this message translates to:
  /// **'Droits totaux'**
  String get simulations_transmission_total_rights;

  /// No description provided for @simulations_transmission_amount_per_beneficiary.
  ///
  /// In fr, this message translates to:
  /// **'Montant / bénéficiaire'**
  String get simulations_transmission_amount_per_beneficiary;

  /// No description provided for @simulations_transmission_taxable_per_beneficiary.
  ///
  /// In fr, this message translates to:
  /// **'Taxable / bénéficiaire'**
  String get simulations_transmission_taxable_per_beneficiary;

  /// No description provided for @simulations_transmission_rights_per_beneficiary.
  ///
  /// In fr, this message translates to:
  /// **'Droits / bénéficiaire'**
  String get simulations_transmission_rights_per_beneficiary;

  /// No description provided for @simulations_transmission_estimated_inheritance_rights.
  ///
  /// In fr, this message translates to:
  /// **'Droits de succession estimés'**
  String get simulations_transmission_estimated_inheritance_rights;

  /// No description provided for @simulations_transmission_estate_breakdown.
  ///
  /// In fr, this message translates to:
  /// **'Répartition de la succession'**
  String get simulations_transmission_estate_breakdown;

  /// No description provided for @simulations_transmission_spouse_exempt_part.
  ///
  /// In fr, this message translates to:
  /// **'Part conjoint exonérée'**
  String get simulations_transmission_spouse_exempt_part;

  /// No description provided for @simulations_transmission_children_mass.
  ///
  /// In fr, this message translates to:
  /// **'Masse enfants'**
  String get simulations_transmission_children_mass;

  /// No description provided for @simulations_transmission_children_total_rights.
  ///
  /// In fr, this message translates to:
  /// **'Droits totaux enfants'**
  String get simulations_transmission_children_total_rights;

  /// No description provided for @simulations_transmission_children_transferred_mass.
  ///
  /// In fr, this message translates to:
  /// **'Masse transmise aux enfants'**
  String get simulations_transmission_children_transferred_mass;

  /// No description provided for @simulations_transmission_gross_part_per_child.
  ///
  /// In fr, this message translates to:
  /// **'Part brute / enfant'**
  String get simulations_transmission_gross_part_per_child;

  /// No description provided for @simulations_transmission_taxable_per_child.
  ///
  /// In fr, this message translates to:
  /// **'Taxable / enfant'**
  String get simulations_transmission_taxable_per_child;

  /// No description provided for @simulations_transmission_rights_per_child.
  ///
  /// In fr, this message translates to:
  /// **'Droits / enfant'**
  String get simulations_transmission_rights_per_child;

  /// No description provided for @simulations_transmission_net_per_child.
  ///
  /// In fr, this message translates to:
  /// **'Net / enfant'**
  String get simulations_transmission_net_per_child;

  /// No description provided for @simulations_transmission_surviving_spouse.
  ///
  /// In fr, this message translates to:
  /// **'Conjoint survivant'**
  String get simulations_transmission_surviving_spouse;

  /// No description provided for @simulations_transmission_spouse_share.
  ///
  /// In fr, this message translates to:
  /// **'Part attribuée au conjoint'**
  String get simulations_transmission_spouse_share;

  /// No description provided for @simulations_transmission_number_inheriting_children.
  ///
  /// In fr, this message translates to:
  /// **'Nombre d\'enfants héritiers'**
  String get simulations_transmission_number_inheriting_children;

  /// No description provided for @simulations_transmission_net_estate_assets.
  ///
  /// In fr, this message translates to:
  /// **'Actif net successoral'**
  String get simulations_transmission_net_estate_assets;

  /// No description provided for @simulations_transmission_abatement_per_child.
  ///
  /// In fr, this message translates to:
  /// **'Abattement par enfant'**
  String get simulations_transmission_abatement_per_child;

  /// No description provided for @simulations_transmission_disclaimer_demembrement.
  ///
  /// In fr, this message translates to:
  /// **'Barème de valorisation usufruit/nue-propriété selon l\'article 669 CGI (référentiel 2026). Simulation indicative, hors clauses civiles spécifiques, réserve/usufruit successif et optimisation notariale personnalisée.'**
  String get simulations_transmission_disclaimer_demembrement;

  /// No description provided for @simulations_transmission_disclaimer_donation.
  ///
  /// In fr, this message translates to:
  /// **'Barèmes simplifiés de droits de donation 2026. Abattements simulés par lien de parenté, hors dons familiaux de sommes d\'argent, rapport fiscal, réductions spécifiques ou passif déductible.'**
  String get simulations_transmission_disclaimer_donation;

  /// No description provided for @simulations_transmission_disclaimer_heritage.
  ///
  /// In fr, this message translates to:
  /// **'Référentiel succession 2026 simplifié : conjoint/PACS exonéré, barème ligne directe pour enfants. Ne tient pas compte des options civiles détaillées (usufruit légal du conjoint, quotité disponible, testament, assurance-vie).'**
  String get simulations_transmission_disclaimer_heritage;

  /// No description provided for @simulations_estimation_property_address.
  ///
  /// In fr, this message translates to:
  /// **'Adresse du bien'**
  String get simulations_estimation_property_address;

  /// No description provided for @simulations_estimation_price_per_sqm.
  ///
  /// In fr, this message translates to:
  /// **'Prix au m²'**
  String get simulations_estimation_price_per_sqm;

  /// No description provided for @simulations_estimation_rent_per_sqm.
  ///
  /// In fr, this message translates to:
  /// **'Loyer au m²'**
  String get simulations_estimation_rent_per_sqm;

  /// No description provided for @simulations_estimation_property_usage.
  ///
  /// In fr, this message translates to:
  /// **'Usage du bien'**
  String get simulations_estimation_property_usage;

  /// No description provided for @simulations_estimation_usage_locatif.
  ///
  /// In fr, this message translates to:
  /// **'Investissement locatif'**
  String get simulations_estimation_usage_locatif;

  /// No description provided for @simulations_estimation_usage_residence.
  ///
  /// In fr, this message translates to:
  /// **'Résidence principale/secondaire'**
  String get simulations_estimation_usage_residence;

  /// No description provided for @simulations_estimation_property_type.
  ///
  /// In fr, this message translates to:
  /// **'Type de bien'**
  String get simulations_estimation_property_type;

  /// No description provided for @simulations_estimation_type_maison.
  ///
  /// In fr, this message translates to:
  /// **'Maison'**
  String get simulations_estimation_type_maison;

  /// No description provided for @simulations_estimation_type_appartement.
  ///
  /// In fr, this message translates to:
  /// **'Appartement'**
  String get simulations_estimation_type_appartement;

  /// No description provided for @simulations_estimation_field_surface.
  ///
  /// In fr, this message translates to:
  /// **'Surface'**
  String get simulations_estimation_field_surface;

  /// No description provided for @simulations_estimation_field_price_per_sqm.
  ///
  /// In fr, this message translates to:
  /// **'Prix au m² (corrigeable)'**
  String get simulations_estimation_field_price_per_sqm;

  /// No description provided for @simulations_estimation_rental_units.
  ///
  /// In fr, this message translates to:
  /// **'Unités locatives'**
  String get simulations_estimation_rental_units;

  /// No description provided for @simulations_estimation_unit_number.
  ///
  /// In fr, this message translates to:
  /// **'Unité {n}'**
  String simulations_estimation_unit_number(int n);

  /// No description provided for @simulations_estimation_financing.
  ///
  /// In fr, this message translates to:
  /// **'Financement'**
  String get simulations_estimation_financing;

  /// No description provided for @simulations_estimation_field_travaux.
  ///
  /// In fr, this message translates to:
  /// **'Travaux'**
  String get simulations_estimation_field_travaux;

  /// No description provided for @simulations_estimation_field_frais_notaire.
  ///
  /// In fr, this message translates to:
  /// **'Frais de notaire'**
  String get simulations_estimation_field_frais_notaire;

  /// No description provided for @simulations_estimation_field_charges_annuelles.
  ///
  /// In fr, this message translates to:
  /// **'Charges annuelles (copro, taxe foncière, assurance...)'**
  String get simulations_estimation_field_charges_annuelles;

  /// No description provided for @simulations_estimation_cash_purchase.
  ///
  /// In fr, this message translates to:
  /// **'Achat comptant (sans crédit)'**
  String get simulations_estimation_cash_purchase;

  /// No description provided for @simulations_estimation_derived_loan_amount.
  ///
  /// In fr, this message translates to:
  /// **'Montant emprunté (dérivé) : {amount}'**
  String simulations_estimation_derived_loan_amount(String amount);

  /// No description provided for @simulations_estimation_loan_info.
  ///
  /// In fr, this message translates to:
  /// **'Apport {apport}, taux {taux} % sur {duree} ans, assurance {assurance}/mois — réglés dans l\'onglet Prêt.'**
  String simulations_estimation_loan_info(
    String apport,
    String taux,
    int duree,
    String assurance,
  );

  /// No description provided for @simulations_estimation_use_configured_loan.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser le prêt configuré'**
  String get simulations_estimation_use_configured_loan;

  /// No description provided for @simulations_estimation_estimated_price.
  ///
  /// In fr, this message translates to:
  /// **'Prix estimé du bien'**
  String get simulations_estimation_estimated_price;

  /// No description provided for @simulations_estimation_estimation_in_progress.
  ///
  /// In fr, this message translates to:
  /// **'Estimation en cours...'**
  String get simulations_estimation_estimation_in_progress;

  /// No description provided for @simulations_estimation_comparable_sales_info.
  ///
  /// In fr, this message translates to:
  /// **'Basé sur {sampleSize} vente(s) comparable(s) {scope}, {years}.'**
  String simulations_estimation_comparable_sales_info(
    int sampleSize,
    String scope,
    String years,
  );

  /// No description provided for @simulations_estimation_no_comparable_sales.
  ///
  /// In fr, this message translates to:
  /// **'Aucune vente comparable trouvée — prix à ajuster manuellement.'**
  String get simulations_estimation_no_comparable_sales;

  /// No description provided for @simulations_estimation_rent_estimation_in_progress.
  ///
  /// In fr, this message translates to:
  /// **'Estimation du loyer en cours...'**
  String get simulations_estimation_rent_estimation_in_progress;

  /// No description provided for @simulations_estimation_estimated_rent_label.
  ///
  /// In fr, this message translates to:
  /// **'Loyer estimé : '**
  String get simulations_estimation_estimated_rent_label;

  /// No description provided for @simulations_estimation_rent_zone_commune.
  ///
  /// In fr, this message translates to:
  /// **' (commune)'**
  String get simulations_estimation_rent_zone_commune;

  /// No description provided for @simulations_estimation_rent_zone_expanded.
  ///
  /// In fr, this message translates to:
  /// **' (zone élargie)'**
  String get simulations_estimation_rent_zone_expanded;

  /// No description provided for @simulations_estimation_gross_rental_income.
  ///
  /// In fr, this message translates to:
  /// **'Revenu locatif brut'**
  String get simulations_estimation_gross_rental_income;

  /// No description provided for @simulations_estimation_net_rental_income.
  ///
  /// In fr, this message translates to:
  /// **'Revenu locatif net'**
  String get simulations_estimation_net_rental_income;

  /// No description provided for @simulations_estimation_loan_payment.
  ///
  /// In fr, this message translates to:
  /// **'Mensualité crédit'**
  String get simulations_estimation_loan_payment;

  /// No description provided for @simulations_estimation_project_self_financed.
  ///
  /// In fr, this message translates to:
  /// **'Projet autofinancé'**
  String get simulations_estimation_project_self_financed;

  /// No description provided for @simulations_estimation_project_not_self_financed.
  ///
  /// In fr, this message translates to:
  /// **'Projet non autofinancé'**
  String get simulations_estimation_project_not_self_financed;

  /// No description provided for @simulations_estimation_monthly_cash_flow.
  ///
  /// In fr, this message translates to:
  /// **'Cash-flow mensuel : {amount}'**
  String simulations_estimation_monthly_cash_flow(String amount);

  /// No description provided for @simulations_estimation_gross_yield.
  ///
  /// In fr, this message translates to:
  /// **'Rendement brut'**
  String get simulations_estimation_gross_yield;

  /// No description provided for @simulations_estimation_net_yield.
  ///
  /// In fr, this message translates to:
  /// **'Rendement net'**
  String get simulations_estimation_net_yield;

  /// No description provided for @simulations_estimation_total_project_cost.
  ///
  /// In fr, this message translates to:
  /// **'Coût total du projet'**
  String get simulations_estimation_total_project_cost;

  /// No description provided for @simulations_estimation_strategy.
  ///
  /// In fr, this message translates to:
  /// **'Stratégie'**
  String get simulations_estimation_strategy;

  /// No description provided for @simulations_estimation_strategy_long_term.
  ///
  /// In fr, this message translates to:
  /// **'Longue durée'**
  String get simulations_estimation_strategy_long_term;

  /// No description provided for @simulations_estimation_strategy_short_term.
  ///
  /// In fr, this message translates to:
  /// **'Courte durée'**
  String get simulations_estimation_strategy_short_term;

  /// No description provided for @simulations_estimation_strategy_seasonal_mix.
  ///
  /// In fr, this message translates to:
  /// **'Mixte saisonnier'**
  String get simulations_estimation_strategy_seasonal_mix;

  /// No description provided for @simulations_estimation_strategy_colocation.
  ///
  /// In fr, this message translates to:
  /// **'Colocation'**
  String get simulations_estimation_strategy_colocation;

  /// No description provided for @simulations_estimation_field_monthly_rent.
  ///
  /// In fr, this message translates to:
  /// **'Loyer mensuel (€)'**
  String get simulations_estimation_field_monthly_rent;

  /// No description provided for @simulations_estimation_field_nightly_rate.
  ///
  /// In fr, this message translates to:
  /// **'Tarif/nuit (€)'**
  String get simulations_estimation_field_nightly_rate;

  /// No description provided for @simulations_estimation_field_occupancy.
  ///
  /// In fr, this message translates to:
  /// **'Occupation (%)'**
  String get simulations_estimation_field_occupancy;

  /// No description provided for @simulations_estimation_field_long_term_months.
  ///
  /// In fr, this message translates to:
  /// **'Mois longue durée'**
  String get simulations_estimation_field_long_term_months;

  /// No description provided for @simulations_estimation_field_long_term_rent.
  ///
  /// In fr, this message translates to:
  /// **'Loyer longue durée (€)'**
  String get simulations_estimation_field_long_term_rent;

  /// No description provided for @simulations_estimation_field_short_term_months.
  ///
  /// In fr, this message translates to:
  /// **'Mois courte durée'**
  String get simulations_estimation_field_short_term_months;

  /// No description provided for @simulations_estimation_field_summer_nightly_rate.
  ///
  /// In fr, this message translates to:
  /// **'Tarif/nuit été (€)'**
  String get simulations_estimation_field_summer_nightly_rate;

  /// No description provided for @simulations_estimation_room_number.
  ///
  /// In fr, this message translates to:
  /// **'Chambre {n}'**
  String simulations_estimation_room_number(int n);

  /// No description provided for @simulations_estimation_add_room.
  ///
  /// In fr, this message translates to:
  /// **'+ Ajouter une chambre'**
  String get simulations_estimation_add_room;

  /// No description provided for @simulations_estimation_unit_default_label.
  ///
  /// In fr, this message translates to:
  /// **'Bien entier'**
  String get simulations_estimation_unit_default_label;

  /// No description provided for @simulations_estimation_whole_township.
  ///
  /// In fr, this message translates to:
  /// **'(commune entière)'**
  String get simulations_estimation_whole_township;

  /// No description provided for @simulations_estimation_within_radius.
  ///
  /// In fr, this message translates to:
  /// **'dans un rayon de {kilometers} km'**
  String simulations_estimation_within_radius(String kilometers);

  /// No description provided for @simulations_estimation_room_default_label.
  ///
  /// In fr, this message translates to:
  /// **'Chambre 1'**
  String get simulations_estimation_room_default_label;

  /// No description provided for @budget_manage_recurring_tooltip.
  ///
  /// In fr, this message translates to:
  /// **'Lignes récurrentes'**
  String get budget_manage_recurring_tooltip;

  /// No description provided for @budget_new_category_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle catégorie'**
  String get budget_new_category_placeholder;

  /// No description provided for @investments_documents_no_transaction_title.
  ///
  /// In fr, this message translates to:
  /// **'Aucune transaction'**
  String get investments_documents_no_transaction_title;

  /// No description provided for @investments_documents_no_transaction_message.
  ///
  /// In fr, this message translates to:
  /// **'Ajoute d\'abord une transaction pour pouvoir y rattacher un document.'**
  String get investments_documents_no_transaction_message;

  /// No description provided for @investments_documents_link_transaction_label.
  ///
  /// In fr, this message translates to:
  /// **'Rattacher à quelle transaction ?'**
  String get investments_documents_link_transaction_label;

  /// No description provided for @investments_documents_empty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun document pour l\'instant.'**
  String get investments_documents_empty;

  /// No description provided for @investments_documents_view_dialog_title.
  ///
  /// In fr, this message translates to:
  /// **'Documents de la transaction'**
  String get investments_documents_view_dialog_title;

  /// No description provided for @investments_documents_view_dialog_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 document — cliquez pour ouvrir.} other{{count} documents — cliquez pour ouvrir.}}'**
  String investments_documents_view_dialog_subtitle(int count);

  /// No description provided for @budget_recurring_templates_dialog_title.
  ///
  /// In fr, this message translates to:
  /// **'Lignes récurrentes — {sectionTitle}'**
  String budget_recurring_templates_dialog_title(String sectionTitle);

  /// No description provided for @budget_recurring_templates_dialog_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Un point de départ réutilisable, pas une règle vivante : modifier un template ne change pas les lignes déjà ajoutées les mois précédents.'**
  String get budget_recurring_templates_dialog_subtitle;

  /// No description provided for @budget_recurring_templates_empty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune ligne récurrente pour l\'instant.'**
  String get budget_recurring_templates_empty;

  /// No description provided for @budget_recurring_templates_apply_now.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer maintenant'**
  String get budget_recurring_templates_apply_now;

  /// No description provided for @investments_edit_account_menu_item.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le compte'**
  String get investments_edit_account_menu_item;

  /// No description provided for @investments_delete_account_menu_item.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le compte'**
  String get investments_delete_account_menu_item;

  /// No description provided for @investments_delete_account_requires_empty_tooltip.
  ///
  /// In fr, this message translates to:
  /// **'Vide-le d\'abord'**
  String get investments_delete_account_requires_empty_tooltip;

  /// No description provided for @investments_reinclude_in_net_worth_menu_item.
  ///
  /// In fr, this message translates to:
  /// **'Réintégrer au patrimoine'**
  String get investments_reinclude_in_net_worth_menu_item;

  /// No description provided for @investments_exclude_from_net_worth_menu_item.
  ///
  /// In fr, this message translates to:
  /// **'Exclure du patrimoine'**
  String get investments_exclude_from_net_worth_menu_item;

  /// No description provided for @investments_import_ibkr_statement_menu_item.
  ///
  /// In fr, this message translates to:
  /// **'Importer un relevé (IBKR)'**
  String get investments_import_ibkr_statement_menu_item;

  /// No description provided for @investments_tab_positions.
  ///
  /// In fr, this message translates to:
  /// **'Positions'**
  String get investments_tab_positions;

  /// No description provided for @investments_tab_transactions.
  ///
  /// In fr, this message translates to:
  /// **'Transactions'**
  String get investments_tab_transactions;

  /// No description provided for @investments_show_all_account_toggle_expanded.
  ///
  /// In fr, this message translates to:
  /// **'Masquer le reste du compte'**
  String get investments_show_all_account_toggle_expanded;

  /// No description provided for @investments_show_all_account_toggle_collapsed.
  ///
  /// In fr, this message translates to:
  /// **'Afficher tout le compte (+{count})'**
  String investments_show_all_account_toggle_collapsed(int count);

  /// No description provided for @projects_new_project.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau projet'**
  String get projects_new_project;

  /// No description provided for @projects_edit_project.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le projet'**
  String get projects_edit_project;

  /// No description provided for @projects_name_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Nom du projet (ex: Achat résidence principale)'**
  String get projects_name_placeholder;

  /// No description provided for @projects_description_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Description (facultatif)'**
  String get projects_description_placeholder;

  /// No description provided for @projects_echeance_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Échéance'**
  String get projects_echeance_placeholder;

  /// No description provided for @projects_rendement_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Rendement attendu (% / an)'**
  String get projects_rendement_placeholder;

  /// No description provided for @projects_apport_mensuel_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Apport mensuel en € (facultatif)'**
  String get projects_apport_mensuel_placeholder;

  /// No description provided for @projects_montant_cible_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Montant cible en € (facultatif)'**
  String get projects_montant_cible_placeholder;

  /// No description provided for @projects_linked_accounts_label.
  ///
  /// In fr, this message translates to:
  /// **'Comptes liés'**
  String get projects_linked_accounts_label;

  /// No description provided for @projects_linked_liabilities_label.
  ///
  /// In fr, this message translates to:
  /// **'Passifs liés'**
  String get projects_linked_liabilities_label;

  /// No description provided for @projects_dangling_links_warning.
  ///
  /// In fr, this message translates to:
  /// **'1 lien ou plus ne se résout plus (élément supprimé depuis).'**
  String get projects_dangling_links_warning;

  /// No description provided for @projects_no_accounts_available.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte disponible.'**
  String get projects_no_accounts_available;

  /// No description provided for @projects_no_liabilities_available.
  ///
  /// In fr, this message translates to:
  /// **'Aucun passif disponible.'**
  String get projects_no_liabilities_available;

  /// No description provided for @projects_trajectory_title.
  ///
  /// In fr, this message translates to:
  /// **'Trajectoire projetée'**
  String get projects_trajectory_title;

  /// No description provided for @projects_stat_rendement_attendu.
  ///
  /// In fr, this message translates to:
  /// **'Rendement attendu'**
  String get projects_stat_rendement_attendu;

  /// No description provided for @projects_stat_apport_mensuel.
  ///
  /// In fr, this message translates to:
  /// **'Apport mensuel'**
  String get projects_stat_apport_mensuel;

  /// No description provided for @projects_stat_temps_restant.
  ///
  /// In fr, this message translates to:
  /// **'Temps restant'**
  String get projects_stat_temps_restant;

  /// No description provided for @projects_stat_montant_actuel.
  ///
  /// In fr, this message translates to:
  /// **'Montant actuel'**
  String get projects_stat_montant_actuel;

  /// No description provided for @projects_stat_reste_a_atteindre.
  ///
  /// In fr, this message translates to:
  /// **'Reste à atteindre'**
  String get projects_stat_reste_a_atteindre;

  /// No description provided for @projects_linked_accounts_liabilities_title.
  ///
  /// In fr, this message translates to:
  /// **'Comptes et passifs liés'**
  String get projects_linked_accounts_liabilities_title;

  /// No description provided for @projects_echeance_deadline_passed.
  ///
  /// In fr, this message translates to:
  /// **'Échéance dépassée'**
  String get projects_echeance_deadline_passed;

  /// No description provided for @projects_echeance_today.
  ///
  /// In fr, this message translates to:
  /// **'Échéance aujourd\'hui'**
  String get projects_echeance_today;

  /// No description provided for @projects_echeance_in_days.
  ///
  /// In fr, this message translates to:
  /// **'Dans {days} jours'**
  String projects_echeance_in_days(int days);

  /// No description provided for @projects_echeance_in_months.
  ///
  /// In fr, this message translates to:
  /// **'Dans {months} mois'**
  String projects_echeance_in_months(int months);

  /// No description provided for @projects_echeance_in_years.
  ///
  /// In fr, this message translates to:
  /// **'Dans {years} ans'**
  String projects_echeance_in_years(int years);

  /// No description provided for @projects_days_count.
  ///
  /// In fr, this message translates to:
  /// **'{days} jours'**
  String projects_days_count(int days);

  /// No description provided for @projects_on_track_label.
  ///
  /// In fr, this message translates to:
  /// **'En bonne voie'**
  String get projects_on_track_label;

  /// No description provided for @projects_off_track_label.
  ///
  /// In fr, this message translates to:
  /// **'En retard'**
  String get projects_off_track_label;

  /// No description provided for @projects_load_error.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les projets. Vérifiez que le dossier Coffre-fort est accessible.'**
  String get projects_load_error;

  /// No description provided for @projects_select_or_create.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionne ou crée un projet'**
  String get projects_select_or_create;

  /// No description provided for @projects_empty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun projet'**
  String get projects_empty;

  /// No description provided for @simulations_taxation_tab_ir.
  ///
  /// In fr, this message translates to:
  /// **'IR'**
  String get simulations_taxation_tab_ir;

  /// No description provided for @simulations_taxation_tab_ifi.
  ///
  /// In fr, this message translates to:
  /// **'IFI'**
  String get simulations_taxation_tab_ifi;

  /// No description provided for @simulations_taxation_tab_pfu.
  ///
  /// In fr, this message translates to:
  /// **'PFU'**
  String get simulations_taxation_tab_pfu;

  /// No description provided for @simulations_taxation_ifi_disclaimer.
  ///
  /// In fr, this message translates to:
  /// **'Simulation IFI indicative basée sur un barème 2026 simplifié, hors dispositifs spécifiques (décote, exonérations particulières, cas de démembrement, plafonnement selon revenus, etc.). Les règles fiscales évoluent régulièrement : vérifiez toujours avec un professionnel avant décision.'**
  String get simulations_taxation_ifi_disclaimer;

  /// No description provided for @simulations_taxation_ir_disclaimer.
  ///
  /// In fr, this message translates to:
  /// **'Simulation d\'impôt sur le revenu indicative avec quotient familial simplifié. Elle n\'intègre pas toutes les situations réelles (charges déductibles, crédits/réductions d\'impôt, revenus spécifiques, plafonnements et règles particulières). Vérifiez le résultat final avec un expert.'**
  String get simulations_taxation_ir_disclaimer;

  /// No description provided for @simulations_taxation_field_ifi_net_worth.
  ///
  /// In fr, this message translates to:
  /// **'Patrimoine immobilier net'**
  String get simulations_taxation_field_ifi_net_worth;

  /// No description provided for @simulations_taxation_reset_parameters.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser les paramètres'**
  String get simulations_taxation_reset_parameters;

  /// No description provided for @simulations_taxation_ifi_summary_prefix.
  ///
  /// In fr, this message translates to:
  /// **'Cette année, vous avez un patrimoine immobilier net de '**
  String get simulations_taxation_ifi_summary_prefix;

  /// No description provided for @simulations_taxation_ifi_summary_middle.
  ///
  /// In fr, this message translates to:
  /// **', induisant un impôt sur la fortune immobilière total de '**
  String get simulations_taxation_ifi_summary_middle;

  /// No description provided for @simulations_taxation_summary_equivalent_suffix.
  ///
  /// In fr, this message translates to:
  /// **', soit l\'équivalent de '**
  String get simulations_taxation_summary_equivalent_suffix;

  /// No description provided for @simulations_taxation_legend_amount.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get simulations_taxation_legend_amount;

  /// No description provided for @simulations_taxation_legend_bracket_max.
  ///
  /// In fr, this message translates to:
  /// **'Montant max de la tranche'**
  String get simulations_taxation_legend_bracket_max;

  /// No description provided for @simulations_taxation_legend_tax.
  ///
  /// In fr, this message translates to:
  /// **'Impôt'**
  String get simulations_taxation_legend_tax;

  /// No description provided for @simulations_taxation_ifi_stat_max_rate.
  ///
  /// In fr, this message translates to:
  /// **'Taux maximal d\'imposition'**
  String get simulations_taxation_ifi_stat_max_rate;

  /// No description provided for @simulations_taxation_ifi_stat_total_monthly.
  ///
  /// In fr, this message translates to:
  /// **'IFI (total & mensualisé)'**
  String get simulations_taxation_ifi_stat_total_monthly;

  /// No description provided for @simulations_taxation_pfu_field_envelope.
  ///
  /// In fr, this message translates to:
  /// **'Enveloppe'**
  String get simulations_taxation_pfu_field_envelope;

  /// No description provided for @simulations_taxation_pfu_field_data_source.
  ///
  /// In fr, this message translates to:
  /// **'Source des données'**
  String get simulations_taxation_pfu_field_data_source;

  /// No description provided for @simulations_taxation_pfu_mode_manual.
  ///
  /// In fr, this message translates to:
  /// **'Saisie manuelle'**
  String get simulations_taxation_pfu_mode_manual;

  /// No description provided for @simulations_taxation_pfu_mode_existing_account.
  ///
  /// In fr, this message translates to:
  /// **'Compte existant'**
  String get simulations_taxation_pfu_mode_existing_account;

  /// No description provided for @simulations_taxation_pfu_field_choose_account.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un compte'**
  String get simulations_taxation_pfu_field_choose_account;

  /// No description provided for @simulations_taxation_pfu_select_account_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner…'**
  String get simulations_taxation_pfu_select_account_placeholder;

  /// No description provided for @simulations_taxation_pfu_no_account_found.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte {envelope} trouvé dans le patrimoine.'**
  String simulations_taxation_pfu_no_account_found(String envelope);

  /// No description provided for @simulations_taxation_pfu_field_opening_date.
  ///
  /// In fr, this message translates to:
  /// **'Date d\'ouverture du compte'**
  String get simulations_taxation_pfu_field_opening_date;

  /// No description provided for @simulations_taxation_field_invested_amount.
  ///
  /// In fr, this message translates to:
  /// **'Montant investi'**
  String get simulations_taxation_field_invested_amount;

  /// No description provided for @simulations_taxation_field_current_value.
  ///
  /// In fr, this message translates to:
  /// **'Valeur actuelle'**
  String get simulations_taxation_field_current_value;

  /// No description provided for @simulations_taxation_field_withdrawal_amount.
  ///
  /// In fr, this message translates to:
  /// **'Montant du retrait'**
  String get simulations_taxation_field_withdrawal_amount;

  /// No description provided for @simulations_taxation_pfu_summary_withdrawal_exempt_prefix.
  ///
  /// In fr, this message translates to:
  /// **'Retrait {envelope} après 5 ans : '**
  String simulations_taxation_pfu_summary_withdrawal_exempt_prefix(
    String envelope,
  );

  /// No description provided for @simulations_taxation_pfu_summary_withdrawal_prefix.
  ///
  /// In fr, this message translates to:
  /// **'Retrait {envelope} : '**
  String simulations_taxation_pfu_summary_withdrawal_prefix(String envelope);

  /// No description provided for @simulations_taxation_pfu_summary_tax_exempt.
  ///
  /// In fr, this message translates to:
  /// **'exonéré d\'impôts'**
  String get simulations_taxation_pfu_summary_tax_exempt;

  /// No description provided for @simulations_taxation_pfu_summary_gain_prefix.
  ///
  /// In fr, this message translates to:
  /// **'gain de '**
  String get simulations_taxation_pfu_summary_gain_prefix;

  /// No description provided for @simulations_taxation_pfu_summary_pfu_tax_prefix.
  ///
  /// In fr, this message translates to:
  /// **', impôt PFU de '**
  String get simulations_taxation_pfu_summary_pfu_tax_prefix;

  /// No description provided for @simulations_taxation_pfu_summary_net_received_prefix.
  ///
  /// In fr, this message translates to:
  /// **', net reçu '**
  String get simulations_taxation_pfu_summary_net_received_prefix;

  /// No description provided for @simulations_taxation_pfu_exempt_message.
  ///
  /// In fr, this message translates to:
  /// **'Votre retrait est totalement exonéré d\'impôts.'**
  String get simulations_taxation_pfu_exempt_message;

  /// No description provided for @simulations_taxation_pfu_exempt_explanation.
  ///
  /// In fr, this message translates to:
  /// **'Les gains d\'un PEA sont exonérés d\'IR et de PS après 5 ans de détention.'**
  String get simulations_taxation_pfu_exempt_explanation;

  /// No description provided for @simulations_taxation_pfu_stat_unrealized_gain.
  ///
  /// In fr, this message translates to:
  /// **'Gain latent'**
  String get simulations_taxation_pfu_stat_unrealized_gain;

  /// No description provided for @simulations_taxation_pfu_stat_taxable_gain.
  ///
  /// In fr, this message translates to:
  /// **'Gain imposable'**
  String get simulations_taxation_pfu_stat_taxable_gain;

  /// No description provided for @simulations_taxation_pfu_stat_ir_rate.
  ///
  /// In fr, this message translates to:
  /// **'IR (PFU {rate}%)'**
  String simulations_taxation_pfu_stat_ir_rate(String rate);

  /// No description provided for @simulations_taxation_pfu_stat_ps_rate.
  ///
  /// In fr, this message translates to:
  /// **'PS (PFU {rate}%)'**
  String simulations_taxation_pfu_stat_ps_rate(String rate);

  /// No description provided for @simulations_taxation_pfu_stat_total.
  ///
  /// In fr, this message translates to:
  /// **'PFU total'**
  String get simulations_taxation_pfu_stat_total;

  /// No description provided for @simulations_taxation_pfu_stat_net_received.
  ///
  /// In fr, this message translates to:
  /// **'Montant net reçu'**
  String get simulations_taxation_pfu_stat_net_received;

  /// No description provided for @simulations_taxation_pfu_comparison_title.
  ///
  /// In fr, this message translates to:
  /// **'Comparaison : PFU vs barème progressif'**
  String get simulations_taxation_pfu_comparison_title;

  /// No description provided for @simulations_taxation_pfu_stat_bareme_ir.
  ///
  /// In fr, this message translates to:
  /// **'Barème IR'**
  String get simulations_taxation_pfu_stat_bareme_ir;

  /// No description provided for @simulations_taxation_pfu_stat_bareme_ps.
  ///
  /// In fr, this message translates to:
  /// **'Barème PS'**
  String get simulations_taxation_pfu_stat_bareme_ps;

  /// No description provided for @simulations_taxation_pfu_stat_bareme_total.
  ///
  /// In fr, this message translates to:
  /// **'Barème total'**
  String get simulations_taxation_pfu_stat_bareme_total;

  /// No description provided for @simulations_taxation_pfu_stat_net_after_bareme.
  ///
  /// In fr, this message translates to:
  /// **'Net après barème'**
  String get simulations_taxation_pfu_stat_net_after_bareme;

  /// No description provided for @simulations_taxation_pfu_wins_label.
  ///
  /// In fr, this message translates to:
  /// **'Le PFU est plus avantageux'**
  String get simulations_taxation_pfu_wins_label;

  /// No description provided for @simulations_taxation_bareme_wins_label.
  ///
  /// In fr, this message translates to:
  /// **'Le barème est plus avantageux'**
  String get simulations_taxation_bareme_wins_label;

  /// No description provided for @simulations_taxation_pfu_comparison_savings.
  ///
  /// In fr, this message translates to:
  /// **'{label} ({amount} d\'économie)'**
  String simulations_taxation_pfu_comparison_savings(
    String label,
    String amount,
  );

  /// No description provided for @simulations_taxation_pfu_about_title.
  ///
  /// In fr, this message translates to:
  /// **'À propos du PFU (flat tax)'**
  String get simulations_taxation_pfu_about_title;

  /// No description provided for @simulations_taxation_pfu_about_body.
  ///
  /// In fr, this message translates to:
  /// **'Le PFU est un prélèvement forfaitaire unique de 31,4 % (12,8 % IR + 18,6 % PS) sur les plus-values de cession. Pour les PEA, les gains sont exonérés après 5 ans. Pour les Assurance-Vie, un abattement annuel de 4 600 € (9 200 € après 8 ans) s\'applique avant taxation.'**
  String get simulations_taxation_pfu_about_body;

  /// No description provided for @simulations_taxation_pfu_about_rates_note.
  ///
  /// In fr, this message translates to:
  /// **'Les taux utilisés proviennent de Réglages → Paramètres fiscaux et peuvent être personnalisés.'**
  String get simulations_taxation_pfu_about_rates_note;

  /// No description provided for @simulations_taxation_field_taxable_income.
  ///
  /// In fr, this message translates to:
  /// **'Revenu net imposable'**
  String get simulations_taxation_field_taxable_income;

  /// No description provided for @simulations_taxation_field_parts.
  ///
  /// In fr, this message translates to:
  /// **'Nombre de parts'**
  String get simulations_taxation_field_parts;

  /// No description provided for @simulations_taxation_ir_summary_prefix.
  ///
  /// In fr, this message translates to:
  /// **'Cette année, vous avez un net imposable de '**
  String get simulations_taxation_ir_summary_prefix;

  /// No description provided for @simulations_taxation_ir_summary_middle.
  ///
  /// In fr, this message translates to:
  /// **', induisant un impôt sur le revenu total de '**
  String get simulations_taxation_ir_summary_middle;

  /// No description provided for @simulations_taxation_ir_stat_quotient.
  ///
  /// In fr, this message translates to:
  /// **'Quotient familial'**
  String get simulations_taxation_ir_stat_quotient;

  /// No description provided for @simulations_taxation_ir_stat_marginal_rate.
  ///
  /// In fr, this message translates to:
  /// **'Taux marginal d\'imposition'**
  String get simulations_taxation_ir_stat_marginal_rate;

  /// No description provided for @simulations_taxation_ir_stat_total_monthly.
  ///
  /// In fr, this message translates to:
  /// **'Impôt sur le revenu (total & mensualisé)'**
  String get simulations_taxation_ir_stat_total_monthly;

  /// No description provided for @simulations_taxation_bracket_tooltip_title.
  ///
  /// In fr, this message translates to:
  /// **'Tranche {label}'**
  String simulations_taxation_bracket_tooltip_title(String label);

  /// No description provided for @simulations_taxation_bracket_tooltip_max.
  ///
  /// In fr, this message translates to:
  /// **'Montant max'**
  String get simulations_taxation_bracket_tooltip_max;

  /// No description provided for @simulations_taxation_date_day_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'JJ'**
  String get simulations_taxation_date_day_placeholder;

  /// No description provided for @simulations_taxation_date_month_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'MM'**
  String get simulations_taxation_date_month_placeholder;

  /// No description provided for @simulations_taxation_date_year_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'AAAA'**
  String get simulations_taxation_date_year_placeholder;

  /// No description provided for @investments_section_title.
  ///
  /// In fr, this message translates to:
  /// **'Investissements'**
  String get investments_section_title;

  /// No description provided for @investments_identifier_copied_toast_title.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant copié'**
  String get investments_identifier_copied_toast_title;

  /// No description provided for @investments_ticker_copied_toast_title.
  ///
  /// In fr, this message translates to:
  /// **'Ticker copié'**
  String get investments_ticker_copied_toast_title;

  /// No description provided for @investments_quantity_units_suffix.
  ///
  /// In fr, this message translates to:
  /// **'unités'**
  String get investments_quantity_units_suffix;

  /// No description provided for @investments_add_investment_button.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un investissement'**
  String get investments_add_investment_button;

  /// No description provided for @investments_establishment_select_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Établissement (banque)'**
  String get investments_establishment_select_placeholder;

  /// No description provided for @investments_clear_opening_date_button.
  ///
  /// In fr, this message translates to:
  /// **'Effacer la date'**
  String get investments_clear_opening_date_button;

  /// No description provided for @strategy_documents_button_label.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Documents} other{Documents ({count})}}'**
  String strategy_documents_button_label(int count);

  /// No description provided for @strategy_editor_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Écris ta stratégie...'**
  String get strategy_editor_placeholder;

  /// No description provided for @strategy_load_error.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les notes. Vérifiez que le dossier Coffre-fort est accessible.'**
  String get strategy_load_error;

  /// No description provided for @strategy_select_or_create.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionne ou crée une note'**
  String get strategy_select_or_create;

  /// No description provided for @strategy_new_folder_title.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau dossier'**
  String get strategy_new_folder_title;

  /// No description provided for @strategy_rename_folder_title.
  ///
  /// In fr, this message translates to:
  /// **'Renommer le dossier'**
  String get strategy_rename_folder_title;

  /// No description provided for @strategy_folder_name_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Nom du dossier'**
  String get strategy_folder_name_placeholder;

  /// No description provided for @strategy_folder_color_title.
  ///
  /// In fr, this message translates to:
  /// **'Couleur du dossier'**
  String get strategy_folder_color_title;

  /// No description provided for @strategy_delete_folder_confirm_title.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer \"{name}\" ?'**
  String strategy_delete_folder_confirm_title(String name);

  /// No description provided for @strategy_delete_folder_confirm_message.
  ///
  /// In fr, this message translates to:
  /// **'Les notes qu\'il contient ne seront pas supprimées, seulement rangées de nouveau hors dossier.'**
  String get strategy_delete_folder_confirm_message;

  /// No description provided for @strategy_move_to_folder_title.
  ///
  /// In fr, this message translates to:
  /// **'Déplacer vers un dossier'**
  String get strategy_move_to_folder_title;

  /// No description provided for @strategy_no_folder_label.
  ///
  /// In fr, this message translates to:
  /// **'Sans dossier'**
  String get strategy_no_folder_label;

  /// No description provided for @strategy_duplicate_note_menu_item.
  ///
  /// In fr, this message translates to:
  /// **'Dupliquer'**
  String get strategy_duplicate_note_menu_item;

  /// No description provided for @strategy_notes_panel_title.
  ///
  /// In fr, this message translates to:
  /// **'Notes'**
  String get strategy_notes_panel_title;

  /// No description provided for @strategy_search_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une note...'**
  String get strategy_search_placeholder;

  /// No description provided for @strategy_no_notes.
  ///
  /// In fr, this message translates to:
  /// **'Aucune note'**
  String get strategy_no_notes;

  /// No description provided for @strategy_change_color_menu_item.
  ///
  /// In fr, this message translates to:
  /// **'Changer la couleur'**
  String get strategy_change_color_menu_item;

  /// No description provided for @investments_price_fresh_badge.
  ///
  /// In fr, this message translates to:
  /// **'à jour'**
  String get investments_price_fresh_badge;

  /// No description provided for @investments_price_manual_badge.
  ///
  /// In fr, this message translates to:
  /// **'manuel'**
  String get investments_price_manual_badge;

  /// No description provided for @investments_manual_price_estimated_on.
  ///
  /// In fr, this message translates to:
  /// **'Estimé le {date}'**
  String investments_manual_price_estimated_on(String date);

  /// No description provided for @investments_excluded_from_patrimoine_badge.
  ///
  /// In fr, this message translates to:
  /// **'Hors patrimoine global'**
  String get investments_excluded_from_patrimoine_badge;

  /// No description provided for @investments_documents_attached_tooltip.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 document rattaché} other{{count} documents rattachés}} — consulter'**
  String investments_documents_attached_tooltip(int count);

  /// No description provided for @investments_transaction_type_arbitrage_label.
  ///
  /// In fr, this message translates to:
  /// **'Arbitrage'**
  String get investments_transaction_type_arbitrage_label;

  /// No description provided for @investments_arbitrage_sold_bought_summary.
  ///
  /// In fr, this message translates to:
  /// **'Vendu {sellQuantity} × {sellPrice} → Acheté {buyQuantity} × {buyPrice}'**
  String investments_arbitrage_sold_bought_summary(
    String sellQuantity,
    String sellPrice,
    String buyQuantity,
    String buyPrice,
  );

  /// No description provided for @investments_manual_price_dialog_title.
  ///
  /// In fr, this message translates to:
  /// **'Cours actuel estimé'**
  String get investments_manual_price_dialog_title;

  /// No description provided for @investments_manual_price_hint_multi_unit.
  ///
  /// In fr, this message translates to:
  /// **'Prix estimé par unité — à mettre à jour toi-même quand tu le juges utile, aucune source de cours automatique n\'existe pour ce placement. La valeur affichée sera ce cours × {quantity} unités détenues.'**
  String investments_manual_price_hint_multi_unit(String quantity);

  /// No description provided for @investments_manual_price_hint_single_unit.
  ///
  /// In fr, this message translates to:
  /// **'À mettre à jour toi-même quand tu le juges utile — aucune source de cours automatique n\'existe pour ce placement.'**
  String get investments_manual_price_hint_single_unit;

  /// No description provided for @investments_field_price_eur.
  ///
  /// In fr, this message translates to:
  /// **'Cours (€)'**
  String get investments_field_price_eur;

  /// No description provided for @investments_pe_valuation_dialog_title.
  ///
  /// In fr, this message translates to:
  /// **'Valorisation actuelle'**
  String get investments_pe_valuation_dialog_title;

  /// No description provided for @investments_pe_valuation_hint.
  ///
  /// In fr, this message translates to:
  /// **'Dernier NAV/valorisation communiqué par le gérant du fonds — à mettre à jour toi-même quand tu le reçois, aucune source de cours automatique n\'existe pour ce placement.'**
  String get investments_pe_valuation_hint;

  /// No description provided for @investments_field_valuation_eur.
  ///
  /// In fr, this message translates to:
  /// **'Valorisation (€)'**
  String get investments_field_valuation_eur;

  /// No description provided for @investments_delete_position_confirm_title.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer \"{label}\" ?'**
  String investments_delete_position_confirm_title(String label);

  /// No description provided for @investments_delete_position_confirm_message.
  ///
  /// In fr, this message translates to:
  /// **'Cette position sera définitivement supprimée.'**
  String get investments_delete_position_confirm_message;

  /// No description provided for @investments_reestimate_pe_valuation_menu_item.
  ///
  /// In fr, this message translates to:
  /// **'Réestimer la valorisation'**
  String get investments_reestimate_pe_valuation_menu_item;

  /// No description provided for @investments_reestimate_price_menu_item.
  ///
  /// In fr, this message translates to:
  /// **'Réestimer le cours'**
  String get investments_reestimate_price_menu_item;

  /// No description provided for @investments_transfer_to_other_account_menu_item.
  ///
  /// In fr, this message translates to:
  /// **'Transférer vers un autre compte'**
  String get investments_transfer_to_other_account_menu_item;

  /// No description provided for @investments_arbitrage_to_other_security_menu_item.
  ///
  /// In fr, this message translates to:
  /// **'Arbitrer vers un autre titre'**
  String get investments_arbitrage_to_other_security_menu_item;

  /// No description provided for @investments_merge_with_other_position_menu_item.
  ///
  /// In fr, this message translates to:
  /// **'Fusionner avec une autre position'**
  String get investments_merge_with_other_position_menu_item;

  /// No description provided for @investments_delete_position_requires_no_transactions_hint.
  ///
  /// In fr, this message translates to:
  /// **'Supprime d\'abord ses transactions'**
  String get investments_delete_position_requires_no_transactions_hint;

  /// No description provided for @investments_delete_position_menu_item.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la position'**
  String get investments_delete_position_menu_item;

  /// No description provided for @investments_isin_copied_toast.
  ///
  /// In fr, this message translates to:
  /// **'ISIN copié'**
  String get investments_isin_copied_toast;

  /// No description provided for @investments_identifier_copied_toast.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant copié'**
  String get investments_identifier_copied_toast;

  /// No description provided for @investments_ticker_copied_toast.
  ///
  /// In fr, this message translates to:
  /// **'Ticker copié'**
  String get investments_ticker_copied_toast;

  /// No description provided for @investments_stat_net_invested_capital.
  ///
  /// In fr, this message translates to:
  /// **'Capital net investi'**
  String get investments_stat_net_invested_capital;

  /// No description provided for @investments_stat_quantity_held.
  ///
  /// In fr, this message translates to:
  /// **'Quantité détenue'**
  String get investments_stat_quantity_held;

  /// No description provided for @investments_stat_vested.
  ///
  /// In fr, this message translates to:
  /// **'Acquis'**
  String get investments_stat_vested;

  /// No description provided for @investments_stat_last_price.
  ///
  /// In fr, this message translates to:
  /// **'Dernier cours'**
  String get investments_stat_last_price;

  /// No description provided for @investments_stat_estimated_price.
  ///
  /// In fr, this message translates to:
  /// **'Cours estimé'**
  String get investments_stat_estimated_price;

  /// No description provided for @investments_stat_valuation.
  ///
  /// In fr, this message translates to:
  /// **'Valorisation'**
  String get investments_stat_valuation;

  /// No description provided for @investments_performance_annualized.
  ///
  /// In fr, this message translates to:
  /// **'{percent} / an'**
  String investments_performance_annualized(String percent);

  /// No description provided for @investments_performance_since_start.
  ///
  /// In fr, this message translates to:
  /// **'{percent} depuis le début'**
  String investments_performance_since_start(String percent);

  /// No description provided for @investments_insufficient_price_history.
  ///
  /// In fr, this message translates to:
  /// **'Pas assez d\'historique de cours pour ce calcul.'**
  String get investments_insufficient_price_history;

  /// No description provided for @investments_insufficient_transaction_history.
  ///
  /// In fr, this message translates to:
  /// **'Pas assez d\'historique de transactions pour ce calcul.'**
  String get investments_insufficient_transaction_history;

  /// No description provided for @investments_pe_valuation_estimated_on.
  ///
  /// In fr, this message translates to:
  /// **'Valorisation estimée le {date} (menu « ⋮ » pour la mettre à jour).'**
  String investments_pe_valuation_estimated_on(String date);

  /// No description provided for @investments_pe_no_valuation_hint.
  ///
  /// In fr, this message translates to:
  /// **'Aucune valorisation renseignée : le montant ci-dessus correspond au capital net investi — menu « ⋮ » pour renseigner le dernier NAV communiqué par le gérant.'**
  String get investments_pe_no_valuation_hint;

  /// No description provided for @investments_manual_price_estimated_on_menu_hint.
  ///
  /// In fr, this message translates to:
  /// **'Cours estimé le {date} (menu « ⋮ » pour le mettre à jour).'**
  String investments_manual_price_estimated_on_menu_hint(String date);

  /// No description provided for @investments_no_manual_price_hint.
  ///
  /// In fr, this message translates to:
  /// **'Aucun cours renseigné : la valorisation ci-dessus correspond au montant net investi — menu « ⋮ » pour en ajouter un.'**
  String get investments_no_manual_price_hint;

  /// No description provided for @investments_price_not_found_yahoo.
  ///
  /// In fr, this message translates to:
  /// **'Cours introuvable sur Yahoo Finance pour « {isin} ».'**
  String investments_price_not_found_yahoo(String isin);

  /// No description provided for @investments_price_not_available_yet.
  ///
  /// In fr, this message translates to:
  /// **'Cours en temps réel pas encore disponible : la valorisation ci-dessus correspond au montant net investi.'**
  String get investments_price_not_available_yet;

  /// No description provided for @investments_no_positions_yet.
  ///
  /// In fr, this message translates to:
  /// **'Aucune position pour l\'instant.'**
  String get investments_no_positions_yet;

  /// No description provided for @investments_no_open_positions_yet.
  ///
  /// In fr, this message translates to:
  /// **'Aucune position ouverte pour l\'instant.'**
  String get investments_no_open_positions_yet;

  /// No description provided for @investments_old_positions_label.
  ///
  /// In fr, this message translates to:
  /// **'Anciennes positions'**
  String get investments_old_positions_label;

  /// No description provided for @investments_delete_leveraged_position_confirm_title.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer \"{market}\" ?'**
  String investments_delete_leveraged_position_confirm_title(String market);

  /// No description provided for @investments_delete_leveraged_position_confirm_message.
  ///
  /// In fr, this message translates to:
  /// **'Cette position sera définitivement supprimée. Cette action est irréversible.'**
  String get investments_delete_leveraged_position_confirm_message;

  /// No description provided for @investments_leveraged_section_title.
  ///
  /// In fr, this message translates to:
  /// **'Positions à effet de levier'**
  String get investments_leveraged_section_title;

  /// No description provided for @investments_add_position_link.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une position'**
  String get investments_add_position_link;

  /// No description provided for @investments_no_leveraged_positions_yet.
  ///
  /// In fr, this message translates to:
  /// **'Aucune position à effet de levier pour l\'instant.'**
  String get investments_no_leveraged_positions_yet;

  /// No description provided for @investments_closed_positions_label.
  ///
  /// In fr, this message translates to:
  /// **'Positions fermées'**
  String get investments_closed_positions_label;

  /// No description provided for @investments_column_entry_label.
  ///
  /// In fr, this message translates to:
  /// **'Entrée'**
  String get investments_column_entry_label;

  /// No description provided for @investments_column_price_label.
  ///
  /// In fr, this message translates to:
  /// **'Cours'**
  String get investments_column_price_label;

  /// No description provided for @investments_column_amount_label.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get investments_column_amount_label;

  /// No description provided for @investments_pnl_roe_column_label.
  ///
  /// In fr, this message translates to:
  /// **'PnL (ROE)'**
  String get investments_pnl_roe_column_label;

  /// No description provided for @investments_refresh_menu_item.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get investments_refresh_menu_item;

  /// No description provided for @investments_close_position_menu_item.
  ///
  /// In fr, this message translates to:
  /// **'Clôturer'**
  String get investments_close_position_menu_item;

  /// No description provided for @investments_position_closed_badge.
  ///
  /// In fr, this message translates to:
  /// **'Fermée'**
  String get investments_position_closed_badge;

  /// No description provided for @investments_liquidation_price_label.
  ///
  /// In fr, this message translates to:
  /// **'Liquidation : {price}'**
  String investments_liquidation_price_label(String price);

  /// No description provided for @investments_delete_investment_confirm_title.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer \"{label}\" ?'**
  String investments_delete_investment_confirm_title(String label);

  /// No description provided for @investments_delete_investment_confirm_message.
  ///
  /// In fr, this message translates to:
  /// **'Cet investissement sera définitivement supprimé.'**
  String get investments_delete_investment_confirm_message;

  /// No description provided for @investments_transfer_to_account_menu_item.
  ///
  /// In fr, this message translates to:
  /// **'Transférer vers un autre compte'**
  String get investments_transfer_to_account_menu_item;

  /// No description provided for @investments_arbitrage_to_security_menu_item.
  ///
  /// In fr, this message translates to:
  /// **'Arbitrer vers un autre titre'**
  String get investments_arbitrage_to_security_menu_item;

  /// No description provided for @investments_merge_with_position_menu_item.
  ///
  /// In fr, this message translates to:
  /// **'Fusionner avec une autre position'**
  String get investments_merge_with_position_menu_item;

  /// No description provided for @investments_delete_investment_requires_empty_tooltip.
  ///
  /// In fr, this message translates to:
  /// **'Supprime d\'abord ses transactions'**
  String get investments_delete_investment_requires_empty_tooltip;

  /// No description provided for @investments_delete_investment_menu_item.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'investissement'**
  String get investments_delete_investment_menu_item;

  /// No description provided for @investments_receipt_save_dialog_title.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer la quittance'**
  String get investments_receipt_save_dialog_title;

  /// No description provided for @investments_receipt_document_name.
  ///
  /// In fr, this message translates to:
  /// **'Quittance {month}'**
  String investments_receipt_document_name(String month);

  /// No description provided for @investments_receipt_saved_toast_title.
  ///
  /// In fr, this message translates to:
  /// **'Quittance enregistrée'**
  String get investments_receipt_saved_toast_title;

  /// No description provided for @investments_receipt_save_failed_toast_title.
  ///
  /// In fr, this message translates to:
  /// **'Échec de l\'enregistrement'**
  String get investments_receipt_save_failed_toast_title;

  /// No description provided for @investments_receipt_save_failed_subtitle.
  ///
  /// In fr, this message translates to:
  /// **'La quittance n\'a pas pu être générée ou enregistrée : {error}'**
  String investments_receipt_save_failed_subtitle(String error);

  /// No description provided for @investments_isin_copied_toast_title.
  ///
  /// In fr, this message translates to:
  /// **'ISIN copié'**
  String get investments_isin_copied_toast_title;

  /// No description provided for @investments_quantity_held_label.
  ///
  /// In fr, this message translates to:
  /// **'Quantité détenue'**
  String get investments_quantity_held_label;

  /// No description provided for @investments_last_price_label.
  ///
  /// In fr, this message translates to:
  /// **'Dernier cours'**
  String get investments_last_price_label;

  /// No description provided for @investments_performance_annualized_label.
  ///
  /// In fr, this message translates to:
  /// **'{rate} / an'**
  String investments_performance_annualized_label(String rate);

  /// No description provided for @investments_performance_since_start_label.
  ///
  /// In fr, this message translates to:
  /// **'{rate} depuis le début'**
  String investments_performance_since_start_label(String rate);

  /// No description provided for @investments_not_enough_price_history.
  ///
  /// In fr, this message translates to:
  /// **'Pas assez d\'historique de cours pour ce calcul.'**
  String get investments_not_enough_price_history;

  /// No description provided for @investments_twr_explanation.
  ///
  /// In fr, this message translates to:
  /// **'TWR (Time-Weighted Return) : performance de l\'actif, indépendamment du moment de vos apports.'**
  String get investments_twr_explanation;

  /// No description provided for @investments_mwr_explanation.
  ///
  /// In fr, this message translates to:
  /// **'MWR (Money-Weighted Return) : rendement réellement perçu, compte tenu du montant et de la date de chaque apport.'**
  String get investments_mwr_explanation;

  /// No description provided for @investments_price_not_found_hint.
  ///
  /// In fr, this message translates to:
  /// **'Cours introuvable sur Yahoo Finance pour « {isin} » : identifiant inconnu ou actif non coté. Vérifiez l\'identifiant — la valorisation ci-dessus correspond au montant net investi (prix d\'achat), pas au cours actuel du marché.'**
  String investments_price_not_found_hint(String isin);

  /// No description provided for @investments_price_not_yet_available_hint.
  ///
  /// In fr, this message translates to:
  /// **'Cours en temps réel pas encore disponible : la valorisation ci-dessus correspond au montant net investi (prix d\'achat), pas au cours actuel du marché.'**
  String get investments_price_not_yet_available_hint;

  /// No description provided for @investments_tab_profitability.
  ///
  /// In fr, this message translates to:
  /// **'Rentabilité'**
  String get investments_tab_profitability;

  /// No description provided for @investments_ibkr_import_dialog_title.
  ///
  /// In fr, this message translates to:
  /// **'Importer le relevé IBKR'**
  String get investments_ibkr_import_dialog_title;

  /// No description provided for @investments_ibkr_period_label.
  ///
  /// In fr, this message translates to:
  /// **'Période : {start} → {end}'**
  String investments_ibkr_period_label(String start, String end);

  /// No description provided for @investments_ibkr_row_security_trades.
  ///
  /// In fr, this message translates to:
  /// **'Achats / ventes de titres'**
  String get investments_ibkr_row_security_trades;

  /// No description provided for @investments_ibkr_row_currency_conversions.
  ///
  /// In fr, this message translates to:
  /// **'Conversions de devise'**
  String get investments_ibkr_row_currency_conversions;

  /// No description provided for @investments_ibkr_row_dividends.
  ///
  /// In fr, this message translates to:
  /// **'Dividendes'**
  String get investments_ibkr_row_dividends;

  /// No description provided for @investments_ibkr_row_withholding_tax.
  ///
  /// In fr, this message translates to:
  /// **'Retenues à la source'**
  String get investments_ibkr_row_withholding_tax;

  /// No description provided for @investments_ibkr_row_fees.
  ///
  /// In fr, this message translates to:
  /// **'Frais'**
  String get investments_ibkr_row_fees;

  /// No description provided for @investments_ibkr_row_deposits.
  ///
  /// In fr, this message translates to:
  /// **'Dépôts'**
  String get investments_ibkr_row_deposits;

  /// No description provided for @investments_ibkr_row_withdrawals.
  ///
  /// In fr, this message translates to:
  /// **'Retraits'**
  String get investments_ibkr_row_withdrawals;

  /// No description provided for @investments_ibkr_row_other_flows.
  ///
  /// In fr, this message translates to:
  /// **'Autres mouvements'**
  String get investments_ibkr_row_other_flows;

  /// No description provided for @investments_ibkr_empty_state.
  ///
  /// In fr, this message translates to:
  /// **'Aucune nouvelle transaction à importer — ce fichier a déjà été importé, ou ne contient aucune ligne reconnue.'**
  String get investments_ibkr_empty_state;

  /// No description provided for @investments_ibkr_duplicates_skipped.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 ligne déjà importée — ignorée.} other{{count} lignes déjà importées — ignorées.}}'**
  String investments_ibkr_duplicates_skipped(int count);

  /// No description provided for @investments_ibkr_warnings_title.
  ///
  /// In fr, this message translates to:
  /// **'Avertissements'**
  String get investments_ibkr_warnings_title;

  /// No description provided for @investments_ibkr_import_button.
  ///
  /// In fr, this message translates to:
  /// **'Importer'**
  String get investments_ibkr_import_button;

  /// No description provided for @investments_transfer_title.
  ///
  /// In fr, this message translates to:
  /// **'Transférer \"{label}\"'**
  String investments_transfer_title(String label);

  /// No description provided for @investments_arbitrage_title.
  ///
  /// In fr, this message translates to:
  /// **'Arbitrer \"{label}\"'**
  String investments_arbitrage_title(String label);

  /// No description provided for @investments_transfer_description.
  ///
  /// In fr, this message translates to:
  /// **'Le PRU est conservé : la vente ici et l\'achat sur le compte de destination utilisent tous deux le PRU actuel — aucune plus-value n\'est réalisée par le transfert lui-même.'**
  String get investments_transfer_description;

  /// No description provided for @investments_arbitrage_description.
  ///
  /// In fr, this message translates to:
  /// **'La vente se fait au cours du marché (réalise la plus/moins-value latente) ; le produit finance exactement l\'achat du nouveau titre.'**
  String get investments_arbitrage_description;

  /// No description provided for @investments_field_pru_kept.
  ///
  /// In fr, this message translates to:
  /// **'PRU conservé'**
  String get investments_field_pru_kept;

  /// No description provided for @investments_no_other_account_for_transfer.
  ///
  /// In fr, this message translates to:
  /// **'Aucun autre compte disponible pour un transfert.'**
  String get investments_no_other_account_for_transfer;

  /// No description provided for @investments_field_dest_account.
  ///
  /// In fr, this message translates to:
  /// **'Vers le compte'**
  String get investments_field_dest_account;

  /// No description provided for @investments_field_dest_buy_price.
  ///
  /// In fr, this message translates to:
  /// **'Prix d\'achat de la destination'**
  String get investments_field_dest_buy_price;

  /// No description provided for @investments_amount_obtained_placeholder.
  ///
  /// In fr, this message translates to:
  /// **'Montant obtenu : —'**
  String get investments_amount_obtained_placeholder;

  /// No description provided for @investments_amount_obtained_value.
  ///
  /// In fr, this message translates to:
  /// **'Montant obtenu : {amount}'**
  String investments_amount_obtained_value(String amount);

  /// No description provided for @investments_amount_obtained_with_bought_quantity.
  ///
  /// In fr, this message translates to:
  /// **'Montant obtenu : {amount} → quantité achetée : {quantity}'**
  String investments_amount_obtained_with_bought_quantity(
    String amount,
    String quantity,
  );

  /// No description provided for @investments_transfer_button.
  ///
  /// In fr, this message translates to:
  /// **'Transférer'**
  String get investments_transfer_button;

  /// No description provided for @investments_arbitrage_button.
  ///
  /// In fr, this message translates to:
  /// **'Arbitrer'**
  String get investments_arbitrage_button;

  /// No description provided for @investments_transfer_impossible_title.
  ///
  /// In fr, this message translates to:
  /// **'Transfert impossible'**
  String get investments_transfer_impossible_title;

  /// No description provided for @investments_arbitrage_impossible_title.
  ///
  /// In fr, this message translates to:
  /// **'Arbitrage impossible'**
  String get investments_arbitrage_impossible_title;

  /// No description provided for @investments_error_dest_account_required.
  ///
  /// In fr, this message translates to:
  /// **'Choisis un compte de destination.'**
  String get investments_error_dest_account_required;

  /// No description provided for @investments_error_new_position_fields_required.
  ///
  /// In fr, this message translates to:
  /// **'Renseigne le libellé (et l\'identifiant si nécessaire) de la nouvelle position.'**
  String get investments_error_new_position_fields_required;

  /// No description provided for @investments_error_pru_must_be_positive.
  ///
  /// In fr, this message translates to:
  /// **'Le PRU doit être un nombre supérieur à 0.'**
  String get investments_error_pru_must_be_positive;
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
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
