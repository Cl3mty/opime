// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get academy_button_completed => 'Acquis';

  @override
  String get academy_button_mark_completed => 'Marquer comme acquis';

  @override
  String get academy_disclaimer =>
      'Contenu à vocation éducative et de vulgarisation uniquement, pas un conseil en investissement : nous ne sommes pas conseillers en gestion de patrimoine (CGP). Chacun prend ses décisions financières en son âme et conscience — l\'objectif est simplement de donner au plus grand nombre les clés pour décider en connaissance de cause.';

  @override
  String get academy_takeaway_title => 'À retenir';

  @override
  String get academy_vocabulary_title => 'Vocabulaire';

  @override
  String get analyses_benchmark_chart_not_enough_data =>
      'Pas assez de données sur cette période';

  @override
  String get analyses_stocks_funds_label => 'Actions & Fonds';

  @override
  String get appName => 'Opime';

  @override
  String budget_default_snapshot_name(Object date) {
    return 'Budget du $date';
  }

  @override
  String get common_active => 'Actif';

  @override
  String get common_add => 'Ajouter';

  @override
  String get common_back => 'Retour';

  @override
  String get common_cancel => 'Annuler';

  @override
  String get common_category => 'Catégorie';

  @override
  String get common_close => 'Fermer';

  @override
  String get common_confirm => 'Confirmer';

  @override
  String get common_create => 'Créer';

  @override
  String get common_date => 'Date';

  @override
  String get common_delete => 'Supprimer';

  @override
  String get common_description => 'Description';

  @override
  String get common_edit => 'Modifier';

  @override
  String get common_error => 'Erreur';

  @override
  String get common_loading => 'Chargement...';

  @override
  String get common_name => 'Nom';

  @override
  String get common_next => 'Suivant';

  @override
  String get common_no => 'Non';

  @override
  String get common_none => 'Aucun';

  @override
  String get common_ok => 'OK';

  @override
  String get common_open => 'Ouvrir';

  @override
  String get common_page_not_found => 'Page introuvable';

  @override
  String get common_principal => 'Principal';

  @override
  String get common_remove => 'Supprimer';

  @override
  String get common_rename => 'Renommer';

  @override
  String get common_reset => 'Réinitialiser';

  @override
  String get common_save => 'Enregistrer';

  @override
  String get common_search => 'Rechercher';

  @override
  String get common_see => 'Voir';

  @override
  String get common_switch => 'Basculer';

  @override
  String get common_title => 'Titre';

  @override
  String get common_total => 'TOTAL';

  @override
  String get common_yes => 'Oui';

  @override
  String get dashboard_allocation_title => 'Allocation';

  @override
  String get dashboard_assets_label => 'Actifs';

  @override
  String get dashboard_assets_title => 'Actifs';

  @override
  String get dashboard_liabilities_label => 'Passifs';

  @override
  String get dashboard_not_enough_data_period =>
      'Pas assez de données sur cette période';

  @override
  String get dashboard_onboarding_cta_hint => 'Clique ici pour commencer';

  @override
  String get dashboard_onboarding_empty_description =>
      'Ajoute tes comptes, investissements et crédits pour voir apparaître ton patrimoine, ton allocation et leur évolution. Ça se passe avec le bouton « Compléter mon patrimoine », en haut de l\'écran.';

  @override
  String get dashboard_onboarding_empty_title => 'Ton tableau de bord est vide';

  @override
  String get investments_add_transaction_submit => 'Ajouter la transaction';

  @override
  String get investments_add_transaction_title => 'Ajouter une transaction';

  @override
  String get investments_amount_placeholder => 'Montant : —';

  @override
  String investments_amount_value(String amount) {
    return 'Montant : $amount';
  }

  @override
  String investments_amount_with_bought_quantity(
    String amount,
    String quantity,
  ) {
    return 'Montant : $amount → quantité achetée : $quantity';
  }

  @override
  String investments_delay_days(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String investments_delay_months(int months) {
    return '$months mois';
  }

  @override
  String investments_delay_years(int years) {
    return '$years ans';
  }

  @override
  String get investments_delete_linked_transaction_message =>
      'Cette transaction fait partie d\'un transfert/arbitrage : sa contrepartie sera aussi supprimée. Cette action est irréversible et modifiera la quantité détenue et le PRU des deux positions concernées.';

  @override
  String investments_delete_transaction_message(String label) {
    return 'Cette action est irréversible et modifiera la quantité détenue et le PRU de \"$label\".';
  }

  @override
  String get investments_delete_transaction_title =>
      'Supprimer cette transaction ?';

  @override
  String get investments_edit_arbitrage_title => 'Modifier l\'arbitrage';

  @override
  String get investments_edit_impossible_title => 'Modification impossible';

  @override
  String investments_edit_transaction_title(String label) {
    return 'Modifier la transaction — $label';
  }

  @override
  String get investments_error_buy_price_must_be_positive =>
      'Le prix d\'achat doit être un nombre supérieur à 0.';

  @override
  String get investments_error_date_required => 'La date est requise.';

  @override
  String investments_error_quantity_exceeds_sellable(
    String quantity,
    String maxSellable,
  ) {
    return 'La quantité ($quantity) dépasse la quantité qui serait détenue ($maxSellable).';
  }

  @override
  String get investments_error_quantity_must_be_positive =>
      'La quantité doit être un nombre supérieur à 0.';

  @override
  String get investments_error_sell_price_must_be_positive =>
      'Le prix de vente doit être un nombre supérieur à 0.';

  @override
  String get investments_estimate_button => 'Estimer';

  @override
  String investments_field_amount_currency(String currency) {
    return 'Montant ($currency)';
  }

  @override
  String get investments_field_amount_eur => 'Montant (€)';

  @override
  String get investments_field_amount_paid_eur => 'Montant versé (€)';

  @override
  String get investments_field_buy_price => 'Prix d\'achat';

  @override
  String get investments_field_currency_pair_rate =>
      'Cours de la paire de devise';

  @override
  String get investments_field_position => 'Position';

  @override
  String get investments_field_quantity => 'Quantité';

  @override
  String get investments_field_sell_price => 'Prix de vente';

  @override
  String get investments_field_shares_options_count =>
      'Nombre de titres/options';

  @override
  String get investments_field_total_amount_eur => 'Montant total (€)';

  @override
  String get investments_field_unit_price => 'Prix unitaire';

  @override
  String investments_fiscal_advantage_active_since(String date) {
    return 'Avantage fiscal actif depuis le $date';
  }

  @override
  String investments_fiscal_advantage_upcoming(String date, String delay) {
    return 'Avantage fiscal le $date (dans $delay)';
  }

  @override
  String investments_fx_converted_amount(String amount) {
    return 'Montant ≈ $amount';
  }

  @override
  String get investments_fx_rate_automatic_button => 'Automatique';

  @override
  String investments_fx_rate_display(String currency, String rate) {
    return '1 $currency ≈ $rate €';
  }

  @override
  String get investments_fx_rate_manual_button => 'Taux manuel';

  @override
  String investments_fx_rate_manual_hint(String currency) {
    return 'Taux de change (1 $currency en €)';
  }

  @override
  String get investments_fx_rate_searching => 'Recherche du taux de change…';

  @override
  String get investments_identifier_choose_placeholder => 'Choisir...';

  @override
  String get investments_identifier_generic_hint =>
      'Identifiant (ISIN, ou libre : adresse, référence...)';

  @override
  String get investments_identifier_isin_optional_hint =>
      'ISIN (optionnel : laisse vide si le fonds n\'en a pas)';

  @override
  String get investments_identifier_optional_hint =>
      'Identifiant (optionnel : laisse vide si le fonds n\'en a pas)';

  @override
  String get investments_identifier_reference_hint =>
      'Référence (optionnelle : numéro de série, référence...)';

  @override
  String investments_mwr_annualized(String percent) {
    return '$percent par an (MWR, rendement pondéré par vos apports)';
  }

  @override
  String investments_mwr_since_start(String percent) {
    return '$percent depuis le début (MWR, moins d\'un an de recul)';
  }

  @override
  String get investments_net_invested_amount_pending_price =>
      'Montant net investi (cours pas encore disponible pour tous les investissements)';

  @override
  String get investments_new_position_option => '+ Nouvelle position';

  @override
  String get investments_no_data_yet => 'Pas encore de données.';

  @override
  String get investments_no_transactions_yet =>
      'Aucune transaction pour l\'instant.';

  @override
  String investments_opened_on(String date) {
    return 'Ouvert le $date';
  }

  @override
  String get investments_price_sync_offline_message =>
      'Impossible de mettre à jour les cours et les performances : vérifie ta connexion internet.';

  @override
  String get investments_property_type_apartment => 'Appartement';

  @override
  String get investments_property_type_house => 'Maison';

  @override
  String get investments_reestimate_dialog_title =>
      'Réestimer la valeur (€/m²)';

  @override
  String get investments_reestimate_missing_fields_error =>
      'Renseigne une adresse et une surface.';

  @override
  String get investments_reestimate_no_comparable_sale_error =>
      'Aucune vente comparable trouvée pour cette adresse.';

  @override
  String investments_save_error(String error) {
    return 'Erreur lors de l\'enregistrement : $error';
  }

  @override
  String get investments_surface_m2_label => 'Surface (m²)';

  @override
  String get investments_valuation_last_known_price =>
      'Valorisation au dernier cours connu';

  @override
  String get liabilities_delete_confirm_message =>
      'Ce passif sera définitivement supprimé.';

  @override
  String liabilities_delete_confirm_title(String name) {
    return 'Supprimer \"$name\" ?';
  }

  @override
  String get liabilities_paid_off => 'Soldé';

  @override
  String liabilities_remaining_balance_subtitle(String amount) {
    return 'Capital restant dû, sur $amount empruntés';
  }

  @override
  String get nav_academy => 'Académie';

  @override
  String get nav_analyses => 'Analyses';

  @override
  String get nav_assets => 'Actifs';

  @override
  String get nav_assistant => 'Assistant';

  @override
  String get nav_budget => 'Budget';

  @override
  String get nav_budget_allocation => 'Ventilation';

  @override
  String get nav_budget_tracking => 'Suivi';

  @override
  String get nav_dashboard => 'Tableau de bord';

  @override
  String get nav_entities => 'Entités';

  @override
  String get nav_home => 'Accueil';

  @override
  String get nav_liabilities => 'Passifs';

  @override
  String get nav_patrimoine => 'Patrimoine';

  @override
  String get nav_professional => 'Professionnel';

  @override
  String get nav_projects => 'Projets';

  @override
  String get nav_settings => 'Réglages';

  @override
  String get nav_simulation => 'Simulation';

  @override
  String get nav_simulation_real_estate => 'Immobilier';

  @override
  String get nav_simulation_taxation => 'Fiscalité';

  @override
  String get nav_simulation_transmission => 'Transmission';

  @override
  String get nav_simulation_wealth => 'Patrimoine';

  @override
  String get nav_strategy => 'Stratégie';

  @override
  String get nav_tools => 'Outils';

  @override
  String get settings_account_name_hint => 'Nom (ex: Camille)';

  @override
  String get settings_add_account => 'Ajouter un compte';

  @override
  String get settings_add_vault => 'Ajouter un coffre-fort';

  @override
  String settings_api_key(String provider) {
    return 'Clé API $provider';
  }

  @override
  String get settings_api_key_placeholder => 'Colle ta clé API ici';

  @override
  String get settings_appearance => 'Apparence';

  @override
  String get settings_assistant => 'Assistant IA';

  @override
  String get settings_checking_releases =>
      'Vérification des releases GitHub...';

  @override
  String settings_cloud_description(String provider) {
    return 'Dialogue avec $provider via ta propre clé API : analyses du patrimoine, explications pédagogiques, questions sur tes simulations et ta stratégie.';
  }

  @override
  String get settings_cloud_include_patrimoine =>
      ' et la synthèse de ton patrimoine';

  @override
  String settings_cloud_warning(String provider, String includePatrimoine) {
    return 'Avec $provider, tes messages$includePatrimoine sont envoyés aux serveurs de ce fournisseur, hors de ta machine.';
  }

  @override
  String get settings_comptes => 'Comptes';

  @override
  String get settings_comptes_description =>
      'Sépare le patrimoine, le budget et les notes de stratégie de chaque personne du coffre-fort actif.';

  @override
  String get settings_create_account => 'Créer le compte';

  @override
  String get settings_dark => 'Sombre';

  @override
  String get settings_download_install => 'Télécharger et installer';

  @override
  String get settings_encryption => 'Chiffrement du coffre-fort';

  @override
  String get settings_encryption_disable => 'Désactiver le chiffrement';

  @override
  String get settings_encryption_disabled =>
      'Chiffre les données privées de ce coffre-fort avec un mot de passe que tu définis. Les caches publics (cours de marché, données immobilières, loyers...) restent toujours en clair.';

  @override
  String get settings_encryption_enable => 'Activer le chiffrement';

  @override
  String get settings_encryption_enabled =>
      'Les données privées de ce coffre-fort (comptes, budget, passifs, projets, notes de stratégie, simulations) sont chiffrées. Le mot de passe est redemandé à chaque lancement de l\'app.';

  @override
  String get settings_encryption_regenerate_key =>
      'Générer une nouvelle clé de récupération';

  @override
  String get settings_include_patrimoine_context =>
      'Inclure une synthèse de mon patrimoine dans le contexte du modèle';

  @override
  String get settings_language => 'Langue';

  @override
  String get settings_language_description =>
      'Choisis la langue d\'affichage de l\'application. \"Système\" utilise la langue de ton appareil.';

  @override
  String get settings_language_english => 'Anglais';

  @override
  String get settings_language_french => 'Français';

  @override
  String get settings_language_system => 'Système';

  @override
  String get settings_light => 'Clair';

  @override
  String settings_new_version(String version) {
    return 'Nouvelle version détectée : $version';
  }

  @override
  String get settings_news => 'Actualités';

  @override
  String get settings_news_description =>
      'Actualités Yahoo Finance pour tes actions/ETF détenus, et alertes de variation de prix (CoinGecko) pour tes cryptomonnaies détenues. Aucune requête réseau n\'est effectuée si désactivé.';

  @override
  String get settings_ollama_address => 'Adresse du serveur Ollama';

  @override
  String get settings_ollama_description =>
      'Dialogue avec un modèle Ollama local (gemma, llama...) : analyses du patrimoine, explications pédagogiques, questions sur tes simulations et ta stratégie. Tout reste sur ta machine — aucune donnée n\'est envoyée en ligne. Ollama doit tourner en arrière-plan (« ollama serve ») et les modèles s\'installent avec « ollama pull <modèle> ».';

  @override
  String get settings_ollama_reset_default => 'Rétablir l\'adresse par défaut';

  @override
  String get settings_profile_name => 'Nom';

  @override
  String get settings_profile_name_hint => 'Nom (ex: Camille)';

  @override
  String get settings_profile_relationship => 'Lien de parenté';

  @override
  String get settings_profile_relationship_hint =>
      'Lien de parenté (ex: Épouse)';

  @override
  String get settings_provider => 'Fournisseur';

  @override
  String get settings_relation_name => 'Lien de parenté';

  @override
  String get settings_relationship_hint => 'Lien de parenté (ex: Épouse)';

  @override
  String get settings_remote_version_unknown => 'Version distante inconnue.';

  @override
  String get settings_shortcuts => 'Raccourcis clavier';

  @override
  String get settings_system => 'Système';

  @override
  String get settings_tax_parameters => 'Paramètres fiscaux';

  @override
  String get settings_tax_parameters_description =>
      'Barèmes, seuils et abattements utilisés par les simulateurs (IR, IFI, démembrement, donation, succession) — à jour toi-même en cas de révision par l\'État.';

  @override
  String settings_up_to_date(String version) {
    return 'Vous êtes à jour (latest: $version).';
  }

  @override
  String get settings_update_check_failed =>
      'Impossible de vérifier les mises à jour pour le moment.';

  @override
  String settings_vault_activate_failed(Object error) {
    return 'Impossible d\'activer ce coffre-fort : $error';
  }

  @override
  String settings_vault_add_failed(Object error) {
    return 'Impossible d\'ajouter un coffre-fort : $error';
  }

  @override
  String settings_vault_forget_failed(Object error) {
    return 'Impossible d\'oublier ce coffre-fort : $error';
  }

  @override
  String get settings_vault_name_hint => 'Nom du coffre-fort';

  @override
  String get settings_vault_pick_dialog_title =>
      'Choisis ou crée un coffre-fort Opime';

  @override
  String get settings_vaults => 'Coffres-forts';

  @override
  String get settings_vaults_description =>
      'Ajoute plusieurs coffres-forts, donne-leur un nom, bascule entre eux et oublie-les sans toucher aux données sur disque.';

  @override
  String settings_version_installed(String version) {
    return 'Version installée : $version';
  }

  @override
  String get settings_version_updates => 'Version et mises à jour';

  @override
  String get settings_view_release => 'Voir la release';

  @override
  String get shell_assistant_response_ready => 'Réponse de l\'assistant prête';

  @override
  String get shell_finish_migration_before_export =>
      'Termine la migration du coffre-fort avant d\'exporter.';

  @override
  String get shell_migration_pending => 'Migration en attente';

  @override
  String get shell_no_profile_loaded => 'Aucun profil chargé';

  @override
  String get shell_one_response_ready => 'Une réponse est prête';

  @override
  String get shell_profiles_load_failed =>
      'Impossible de charger les profils. Le dossier Coffre-fort est peut-être encore en cours de synchronisation.';

  @override
  String get shell_response_interrupted => 'Réponse interrompue';

  @override
  String get shell_response_interrupted_subtitle =>
      'Le profil ou le coffre-fort a changé pendant la génération.';

  @override
  String shell_responses_pending(int count) {
    return '$count réponses en attente';
  }

  @override
  String get shell_retry_after_vault_loaded =>
      'Réessaie une fois le coffre-fort chargé.';

  @override
  String get shell_unlock_before_export =>
      'Déverrouille ton coffre-fort avant d\'exporter.';

  @override
  String get shell_vault_locked => 'Coffre-fort verrouillé';

  @override
  String get sidebar_account => 'Compte';

  @override
  String get sidebar_accounts => 'Comptes';

  @override
  String get sidebar_collapse => 'Réduire';

  @override
  String get sidebar_expand => 'Étendre';

  @override
  String get sidebar_switch_account => 'changer de compte';

  @override
  String get academy_envelope_ceiling_label => 'Plafond';

  @override
  String get academy_envelope_good_to_know_title => 'Bon à savoir';

  @override
  String get academy_envelope_ideal_for_label => 'Idéal pour';

  @override
  String get academy_envelope_liquidity_label => 'Liquidité';

  @override
  String get academy_envelope_pitfall_label => 'Piège à éviter — ';

  @override
  String get academy_envelope_taxation_label => 'Fiscalité';

  @override
  String get academy_level_avance => 'Avancé';

  @override
  String get academy_level_debutant => 'Débutant';

  @override
  String get academy_level_intermediaire => 'Intermédiaire';

  @override
  String academy_progress_summary(int count, int total) {
    return '$count / $total acquises';
  }

  @override
  String get assistant_attach_document_tooltip =>
      'Joindre un document (PDF, TXT, MD)';

  @override
  String get assistant_choose_model_first => 'Choisis d\'abord un modèle';

  @override
  String assistant_configure_api_key_prompt(String provider) {
    return 'Configure ta clé API $provider dans Réglages → Assistant IA.';
  }

  @override
  String get assistant_disabled_description =>
      'Active l\'assistant dans les Réglages pour analyser ton patrimoine, expliquer des concepts financiers et répondre à tes questions — avec un modèle Ollama local (aucune donnée ne quitte ta machine) ou un fournisseur cloud connecté via une clé API.';

  @override
  String get assistant_disabled_title => 'Assistant IA désactivé';

  @override
  String get assistant_document_read_error_generic_title =>
      'Erreur lors de la lecture du document';

  @override
  String get assistant_document_read_error_title =>
      'Impossible de lire ce document';

  @override
  String assistant_document_truncated_subtitle(String fileName) {
    return '« $fileName » dépasse la taille prise en charge : seul le début a été transmis à l\'assistant.';
  }

  @override
  String get assistant_document_truncated_title => 'Document tronqué';

  @override
  String get assistant_document_truncated_tooltip =>
      'Document tronqué : seul le début a été transmis à l\'assistant.';

  @override
  String get assistant_empty_state_description =>
      'Pose une question sur ton patrimoine, tes simulations ou ta stratégie. Les réponses s\'appuient sur tes données locales si l\'option de contexte est activée.';

  @override
  String get assistant_empty_state_title => 'Que veux-tu savoir ?';

  @override
  String assistant_error_generic(String error) {
    return 'Erreur : $error';
  }

  @override
  String get assistant_input_placeholder =>
      'Pose une question sur ton patrimoine…';

  @override
  String get assistant_model_placeholder => 'Modèle';

  @override
  String get assistant_model_setup_help =>
      'Pour activer l\'assistant : installe Ollama depuis ollama.com et lance-le, puis exécute « ollama pull llama3.2 » dans un terminal, et clique sur Actualiser.';

  @override
  String get assistant_multiple_responses_generating =>
      'Plusieurs réponses en cours de génération…';

  @override
  String get assistant_new_conversation => 'Nouvelle conversation';

  @override
  String assistant_no_model_cloud(String provider) {
    return 'Aucun modèle disponible pour cette clé $provider.';
  }

  @override
  String get assistant_no_model_ollama =>
      'Aucun modèle n\'est installé sur Ollama.';

  @override
  String get assistant_open_settings => 'Ouvrir les Réglages';

  @override
  String get assistant_refresh_model_list => 'Actualiser la liste';

  @override
  String get assistant_retry => 'Réessayer';

  @override
  String get assistant_send => 'Envoyer';

  @override
  String get assistant_stop_generation => 'Arrêter la génération';

  @override
  String get assistant_suggestion_analyze_patrimoine =>
      'Analyse mon patrimoine';

  @override
  String get assistant_suggestion_explain_allocation =>
      'Explique-moi mon allocation';

  @override
  String get assistant_suggestion_simulations_summary =>
      'Que disent mes simulations ?';

  @override
  String get assistant_suggestion_summarize_strategy => 'Résume ma stratégie';

  @override
  String get budget_add_category => 'Ajouter une catégorie';

  @override
  String get budget_add_revenue_source => 'Ajouter une source de revenu';

  @override
  String get budget_amount_placeholder => 'Montant';

  @override
  String get budget_bucket_dettes => 'Dettes';

  @override
  String get budget_bucket_factures => 'Factures';

  @override
  String get budget_bucket_invest_epargne => 'Invest/Épargne';

  @override
  String get budget_distribution_title => 'Répartition';

  @override
  String budget_duplicate_name_suffix(String name) {
    return '$name (copie)';
  }

  @override
  String get budget_duplicate_tooltip => 'Dupliquer ce budget';

  @override
  String get budget_history_empty => 'Aucun budget sauvegardé.';

  @override
  String get budget_history_title => 'Budgets ventilés';

  @override
  String get budget_inout_header => 'ENTRÉES / SORTIES D\'ARGENT';

  @override
  String get budget_landscape_suggestion =>
      'Utilisez l\'application en mode paysage pour une meilleure lisibilité';

  @override
  String get budget_legend_realite => 'Réalité';

  @override
  String get budget_load_error =>
      'Impossible de charger les budgets. Vérifiez que le dossier Coffre-fort est accessible.';

  @override
  String get budget_month_april => 'avril';

  @override
  String get budget_month_august => 'août';

  @override
  String get budget_month_december => 'décembre';

  @override
  String get budget_month_february => 'février';

  @override
  String get budget_month_flow_title => 'Flux du mois';

  @override
  String get budget_month_january => 'janvier';

  @override
  String get budget_month_july => 'juillet';

  @override
  String get budget_month_june => 'juin';

  @override
  String get budget_month_march => 'mars';

  @override
  String get budget_month_may => 'mai';

  @override
  String get budget_month_november => 'novembre';

  @override
  String get budget_month_october => 'octobre';

  @override
  String get budget_month_september => 'septembre';

  @override
  String get budget_name_placeholder => 'Nom du budget';

  @override
  String get budget_new_budget => 'Nouveau budget';

  @override
  String get budget_no_data => 'Aucune donnée';

  @override
  String get budget_no_results => 'Aucun résultat.';

  @override
  String get budget_redo_shortcut_windows => 'Ctrl+Maj+Z';

  @override
  String budget_redo_tooltip(String shortcut) {
    return 'Rétablir ($shortcut)';
  }

  @override
  String get budget_remaining_amount_label => 'Montant restant';

  @override
  String get budget_revenue_name_placeholder => 'Nom du revenu';

  @override
  String budget_sankey_deficit_label(
    String label,
    String amount,
    String deficit,
  ) {
    return '$label : $amount (déficit de $deficit)';
  }

  @override
  String get budget_sankey_empty_message =>
      'Ajoute des revenus, dépenses ou investissements pour voir le flux.';

  @override
  String get budget_sankey_expense_fallback => 'Dépense';

  @override
  String get budget_sankey_investment_fallback => 'Investissement';

  @override
  String get budget_sankey_no_data_fallback =>
      'Pas encore de données pour ce flux.';

  @override
  String budget_sankey_node_label(String label, String amount) {
    return '$label : $amount';
  }

  @override
  String get budget_sankey_revenue_fallback => 'Revenu';

  @override
  String get budget_sankey_uncategorized => 'Sans catégorie';

  @override
  String get budget_save_chart_dialog_title => 'Enregistrer le graphique';

  @override
  String get budget_saved_toast => 'Budget sauvegardé';

  @override
  String get budget_search_placeholder => 'Rechercher un budget...';

  @override
  String get budget_section_depenses => 'DÉPENSES';

  @override
  String get budget_section_dettes => 'DETTES';

  @override
  String get budget_section_factures => 'FACTURES';

  @override
  String get budget_section_invest_epargne => 'INVEST / ÉPARGNE';

  @override
  String get budget_section_projets => 'PROJETS';

  @override
  String get budget_section_revenues => 'REVENUS';

  @override
  String get budget_summary_available => ' disponible.';

  @override
  String get budget_summary_expenses => ', des dépenses de ';

  @override
  String get budget_summary_inout_title => 'Sommaire des entrées/sorties';

  @override
  String get budget_summary_intro => 'Votre taux d\'épargne est de ';

  @override
  String get budget_summary_invest => ' et investissez ';

  @override
  String get budget_summary_possible_rate => ' (taux d\'épargne possible : ';

  @override
  String get budget_summary_remaining => ' tous les mois, il vous reste ';

  @override
  String get budget_summary_row_depenses => '- Dépenses';

  @override
  String get budget_summary_row_dettes => '- Dettes';

  @override
  String get budget_summary_row_factures => '- Factures';

  @override
  String get budget_summary_row_invest => '- Invest/Épargne';

  @override
  String get budget_summary_row_projets => '- Projets';

  @override
  String get budget_summary_row_remaining => 'RESTANT';

  @override
  String get budget_summary_row_revenues => '+ Revenus';

  @override
  String get budget_summary_total_income => '). Vous avez un revenu total de ';

  @override
  String get budget_tab_expenses => 'Dépenses';

  @override
  String get budget_tab_investments => 'Investissements';

  @override
  String get budget_tab_revenues => 'Revenus';

  @override
  String get budget_templates_nudge_apply => 'Ajouter au mois';

  @override
  String budget_templates_nudge_message(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes récurrentes disponibles — les ajouter à ce mois ?',
      one: '1 ligne récurrente disponible — l\'ajouter à ce mois ?',
    );
    return '$_temp0';
  }

  @override
  String get budget_tracking_sankey_empty_message =>
      'Renseigne des montants dans les colonnes Réalité pour voir le flux de ce mois.';

  @override
  String get budget_tracking_subtitle => 'Tableau de suivi';

  @override
  String budget_undo_tooltip(String shortcut) {
    return 'Annuler ($shortcut)';
  }

  @override
  String get common_continue => 'Continuer';

  @override
  String get common_retry => 'Réessayer';

  @override
  String get core_ui_new_vault_kind_prompt => 'Ce coffre-fort est...';

  @override
  String get core_ui_new_vault_title => 'Nouveau coffre-fort';

  @override
  String get core_ui_pick_date => 'Choisir une date';

  @override
  String get core_ui_vault_kind_personal => 'Personnel';

  @override
  String get dashboard_chart_all_categories => 'Tout';

  @override
  String dashboard_chart_categories_count(int count) {
    return '$count classes';
  }

  @override
  String get dashboard_chart_category_empty => '(vide)';

  @override
  String get dashboard_column_change => 'Évolution';

  @override
  String get dashboard_column_pnl => '+/- value';

  @override
  String get dashboard_column_pru => 'PRU';

  @override
  String get dashboard_column_value => 'Valeur';

  @override
  String get dashboard_extreme_percent_tooltip =>
      'Pourcentage énorme car la période démarre avec un montant très faible (ex : toute première transaction minime) — l\'essentiel de la hausse vient surtout de versements ajoutés depuis, pas d\'une vraie plus-value.';

  @override
  String get dashboard_mwr_tooltip =>
      'Rendement calculé en tenant compte du montant et de la date de chaque versement (méthode MWR) : il reflète le rendement réellement perçu.';

  @override
  String get dashboard_patrimoine_brut_label => 'Patrimoine brut';

  @override
  String get dashboard_patrimoine_net_label => 'Patrimoine net';

  @override
  String get dashboard_top_assets_title => 'Mes meilleures performances';

  @override
  String get dashboard_view_by_account => 'Par compte';

  @override
  String get dashboard_view_by_investment => 'Par investissement';

  @override
  String get entities_accounts_section_title => 'Comptes';

  @override
  String get entities_add_button => 'Ajouter une entité';

  @override
  String entities_card_diluted_suffix(Object percent) {
    return '$percent % vous revient au final';
  }

  @override
  String entities_card_net_total(Object amount) {
    return 'sur $amount net';
  }

  @override
  String entities_card_ownership_direct(String type, String percent) {
    return '$type · $percent % détenu';
  }

  @override
  String entities_card_ownership_via_parent(
    String type,
    String percent,
    String parent,
  ) {
    return '$type · $percent % détenu par $parent';
  }

  @override
  String get entities_delete_confirm_message =>
      'Cette entité sera définitivement supprimée. Ses comptes/passifs existants ne sont pas supprimés, mais ne seront plus rattachés à aucune entité.';

  @override
  String get entities_detail_load_error =>
      'Impossible de charger les comptes de cette entité. Vérifiez que le dossier Coffre-fort est accessible.';

  @override
  String entities_dilution_note(Object name) {
    return 'Ne comptez pas la valeur de cette entité dans le bilan de $name — le lien de possession s\'en charge.';
  }

  @override
  String get entities_editor_edit_title => 'Modifier l\'entité';

  @override
  String get entities_editor_new_title => 'Nouvelle entité';

  @override
  String get entities_empty_list_hint =>
      'Aucune entité pour l\'instant — ajoute un holding, une société commerciale, une SCI ou un compte pro.';

  @override
  String get entities_included_in_net_worth_hint =>
      'Inclus dans votre patrimoine net (Tableau de bord, Analyses).';

  @override
  String get entities_liabilities_section_title => 'Passifs';

  @override
  String get entities_load_error =>
      'Impossible de charger les entités. Vérifiez que le dossier Coffre-fort est accessible.';

  @override
  String get entities_name_hint => 'Nom (ex : Holding Dupont)';

  @override
  String get entities_name_required_error => 'Le nom est obligatoire.';

  @override
  String get entities_net_value_label => 'Valeur nette';

  @override
  String get entities_no_accounts_yet =>
      'Aucun compte pour l\'instant — utilise \"Compléter mon patrimoine\" en choisissant cette entité.';

  @override
  String get entities_no_liabilities_yet => 'Aucun passif pour l\'instant.';

  @override
  String get entities_owned_by_label => 'Détenue par';

  @override
  String get entities_owned_by_self => 'Moi (directement)';

  @override
  String entities_ownership_by_parent(String type, String percent) {
    return '$type · $percent % détenu par sa société mère';
  }

  @override
  String entities_ownership_by_user(String type, String percent) {
    return '$type · $percent % détenu par vous';
  }

  @override
  String get entities_parent_company_fallback => 'sa société mère';

  @override
  String get entities_percent_direct_hint => '% détenu directement par vous';

  @override
  String entities_percent_via_parent_hint(Object name) {
    return '% détenu par $name';
  }

  @override
  String get entities_total_net_value_label =>
      'Valeur nette détenue via les entités professionnelles';

  @override
  String get entities_type_label => 'Type';

  @override
  String get investments_account_description_hint =>
      'Description (facultative, ex: Épargne vacances)';

  @override
  String get investments_account_has_transactions =>
      'contient des transactions';

  @override
  String get investments_account_name_hint_crypto =>
      'Nom du compte (ex: Coinbase)';

  @override
  String get investments_account_name_hint_generic => 'Nom du compte';

  @override
  String get investments_account_name_hint_precious_metals =>
      'Nom du compte (ex: Coffre personnel)';

  @override
  String get investments_account_name_hint_private_equity =>
      'Nom du compte (ex: Moonfare)';

  @override
  String get investments_account_name_hint_real_estate =>
      'Nom du compte (ex: Résidence principale)';

  @override
  String get investments_account_name_hint_savings =>
      'Nom du compte (ex: Livret A)';

  @override
  String get investments_account_name_hint_stocks =>
      'Nom du compte (ex: PEA Boursorama)';

  @override
  String get investments_add_custom_type_label => '+ Nouveau type';

  @override
  String get investments_bank_name_hint => 'Banque (ex: Boursorama)';

  @override
  String get investments_comment_hint => 'Commentaire (facultatif)';

  @override
  String get investments_country_breakdown_title => 'Répartition par pays';

  @override
  String get investments_country_placeholder => 'Pays';

  @override
  String get investments_create_account_label => 'Créer le compte';

  @override
  String get investments_create_investment_label => 'Créer l\'investissement';

  @override
  String get investments_create_liability_label => 'Créer le passif';

  @override
  String get investments_cumulative_funding_number_error =>
      'Le funding cumulé doit être un nombre.';

  @override
  String get investments_delete_account_confirm_message =>
      'Ce compte et ses investissements (sans transaction) seront définitivement supprimés.';

  @override
  String investments_delete_account_confirm_title(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String investments_delete_account_dialog_subtitle(String establishment) {
    return 'Comptes de $establishment — seuls ceux sans transaction sont supprimables.';
  }

  @override
  String get investments_delete_account_dialog_title => 'Supprimer un compte';

  @override
  String get investments_entry_price_label => 'Prix d\'entrée';

  @override
  String get investments_establishment_name_hint =>
      'Nom de l\'établissement (ex: Boursorama)';

  @override
  String get investments_exercise_deadline_hint =>
      'Date limite d\'exercice (facultative)';

  @override
  String get investments_existing_accounts_label => 'Comptes existants';

  @override
  String get investments_finish_without_transaction_label =>
      'Terminer sans transaction';

  @override
  String get investments_fund_style_hint => 'Style de gestion (facultatif)';

  @override
  String get investments_fund_style_placeholder => 'Style de gestion';

  @override
  String get investments_item_name_hint => 'Nom (ex : Rolex Submariner)';

  @override
  String get investments_label_hint_precious_metals =>
      'Libellé (ex: Amundi Physical Gold ETC)';

  @override
  String get investments_label_hint_private_equity =>
      'Libellé (ex: Ardian Expansion Fund)';

  @override
  String get investments_label_hint_stocks => 'Libellé (ex: TotalEnergies)';

  @override
  String get investments_leverage_hint => 'Levier (ex : 2)';

  @override
  String get investments_leveraged_edit_title => 'Modifier la position';

  @override
  String get investments_leveraged_entry_fx_rate_required_error =>
      'Le taux de change du prix d\'entrée est requis.';

  @override
  String get investments_leveraged_entry_price_positive_error =>
      'Le prix d\'entrée doit être un nombre supérieur à 0.';

  @override
  String investments_leveraged_estimated_liquidation(String amount) {
    return 'Liquidation (estimée) : $amount';
  }

  @override
  String get investments_leveraged_leverage_positive_error =>
      'Le levier doit être un nombre supérieur à 0.';

  @override
  String investments_leveraged_margin(String amount) {
    return 'Marge : $amount';
  }

  @override
  String get investments_leveraged_market_required_error =>
      'Le marché (ex : BTC) est requis.';

  @override
  String get investments_leveraged_new_title =>
      'Nouvelle position à effet de levier';

  @override
  String investments_leveraged_notional_amount(String amount) {
    return 'Montant de la position : $amount';
  }

  @override
  String get investments_leveraged_opening_date_required_error =>
      'La date d\'ouverture est requise.';

  @override
  String get investments_leveraged_position_label =>
      'Position à effet de levier';

  @override
  String get investments_leveraged_save_impossible_title =>
      'Position impossible à enregistrer';

  @override
  String get investments_leveraged_size_positive_error =>
      'La taille doit être un nombre supérieur à 0.';

  @override
  String get investments_linked_asset_label => 'Bien financé (facultatif)';

  @override
  String get investments_mark_price_positive_error =>
      'Le cours doit être un nombre supérieur à 0.';

  @override
  String get investments_market_hint => 'Marché (ex : BTC)';

  @override
  String get investments_market_placeholder => 'Marché';

  @override
  String get investments_merge_choose_destination_message =>
      'Choisis la position dans laquelle fusionner.';

  @override
  String investments_merge_dialog_description(String label) {
    return 'Pour corriger une même position saisie deux fois sous des noms différents — pas pour un vrai mouvement financier (voir \"Arbitrer\" pour ça). Toutes les transactions de \"$label\" sont déplacées telles quelles (mêmes dates, quantités, prix) vers la position choisie ci-dessous, puis \"$label\" est supprimée. Cette action est irréversible.';
  }

  @override
  String investments_merge_dialog_title(String label) {
    return 'Fusionner \"$label\"';
  }

  @override
  String get investments_merge_impossible_title => 'Fusion impossible';

  @override
  String get investments_merge_no_other_position_message =>
      'Aucune autre position dans ce compte vers laquelle fusionner.';

  @override
  String get investments_merge_submit_button => 'Fusionner';

  @override
  String get investments_merge_target_label => 'Fusionner vers';

  @override
  String get investments_new_account_section_label => 'Nouveau compte';

  @override
  String get investments_new_custom_type_hint => 'Ex : Vins de collection';

  @override
  String get investments_new_custom_type_title => 'Nouveau type';

  @override
  String investments_next_unlock(String amount, String date) {
    return 'Prochain déblocage : $amount le $date';
  }

  @override
  String get investments_note_hint => 'Note (facultative)';

  @override
  String get investments_opening_date_hint => 'Date d\'ouverture (facultative)';

  @override
  String get investments_opening_date_label => 'Date d\'ouverture';

  @override
  String get investments_real_estate_name_hint =>
      'Nom du bien (ex: Appartement Lyon 6e)';

  @override
  String get investments_refresh_impossible_title => 'Actualisation impossible';

  @override
  String get investments_revert_to_single_value_label =>
      'Revenir à une seule valeur';

  @override
  String get investments_sector_breakdown_title => 'Répartition par secteur';

  @override
  String get investments_sector_placeholder => 'Secteur';

  @override
  String get investments_side_label => 'Sens';

  @override
  String get investments_size_label => 'Taille';

  @override
  String get investments_stop_loss_hint => 'Stop loss (facultatif)';

  @override
  String get investments_take_profit_hint => 'Take profit (facultatif)';

  @override
  String get investments_transaction_buy_label => 'Achat';

  @override
  String get investments_transaction_sell_label => 'Vente';

  @override
  String get investments_unlock_date_hint => 'Date de déblocage';

  @override
  String investments_unlockable_amount(String unlocked, String total) {
    return 'Déblocable : $unlocked sur $total';
  }

  @override
  String get investments_unlocked_on_label => 'Débloqué le';

  @override
  String get investments_vesting_cliff_hint => 'Cliff (mois, facultatif)';

  @override
  String get investments_vesting_duration_hint =>
      'Durée de vesting (mois, facultatif)';

  @override
  String get investments_wizard_account_title => 'Quel compte ?';

  @override
  String get investments_wizard_add_item_label => 'Ajouter la pièce';

  @override
  String get investments_wizard_asset_class_title => 'Quelle classe d\'actif ?';

  @override
  String get investments_wizard_asset_item_title => 'Quel bien ?';

  @override
  String get investments_wizard_asset_label => 'Un actif';

  @override
  String get investments_wizard_asset_sublabel =>
      'Immobilier, bourse, épargne, crypto...';

  @override
  String get investments_wizard_continue_label => 'Continuer';

  @override
  String get investments_wizard_create_currency_label => 'Créer la devise';

  @override
  String get investments_wizard_currency_title => 'Quelle devise ?';

  @override
  String get investments_wizard_establishment_title => 'Quel établissement ?';

  @override
  String get investments_wizard_investment_or_currency_title =>
      'Quel investissement ou devise ?';

  @override
  String get investments_wizard_investment_title => 'Quel investissement ?';

  @override
  String get investments_wizard_item_title => 'Quelle pièce ?';

  @override
  String get investments_wizard_kind_title => 'Que voulez-vous compléter ?';

  @override
  String get investments_wizard_liability_label => 'Un passif';

  @override
  String get investments_wizard_liability_sublabel =>
      'Prêt immobilier, crédit à la consommation...';

  @override
  String get investments_wizard_liability_type_title => 'Quel type de passif ?';

  @override
  String get investments_wizard_new_account_label => 'Nouveau compte';

  @override
  String get investments_wizard_new_asset_item_label => 'Nouveau bien';

  @override
  String get investments_wizard_new_currency_label => 'Nouvelle devise';

  @override
  String get investments_wizard_new_entity_label => 'Nouvelle entité';

  @override
  String get investments_wizard_new_entity_sublabel =>
      'Holding, société commerciale, SCI, compte pro...';

  @override
  String get investments_wizard_new_establishment_label =>
      'Nouvel établissement';

  @override
  String get investments_wizard_new_investment_label => 'Nouvel investissement';

  @override
  String get investments_wizard_new_investment_or_currency_label =>
      'Nouvel investissement ou devise';

  @override
  String get investments_wizard_new_item_label => 'Nouvelle pièce';

  @override
  String get investments_wizard_new_liability_title => 'Nouveau passif';

  @override
  String get investments_wizard_no_precise_type => 'Aucun type précis';

  @override
  String get investments_wizard_owner_title => 'À qui appartient ceci ?';

  @override
  String investments_wizard_step_number(String n) {
    return 'Étape $n';
  }

  @override
  String investments_wizard_step_of_total(String current, String total) {
    return 'Étape $current sur $total';
  }

  @override
  String get investments_wizard_step_preliminary => 'Étape préalable';

  @override
  String get investments_wizard_toggle_currency => 'Devise';

  @override
  String get investments_wizard_toggle_investment => 'Investissement';

  @override
  String get liabilities_deferral_duration_label => 'Durée du différé (mois)';

  @override
  String get liabilities_deferral_partial => 'Partielle';

  @override
  String get liabilities_deferral_total => 'Totale';

  @override
  String get liabilities_deferral_type_label => 'Franchise';

  @override
  String get liabilities_deferred_loan_label => 'Prêt différé';

  @override
  String get liabilities_down_payment_hint => 'Apport (€, 0 si aucun)';

  @override
  String get liabilities_installments_count_label =>
      'Nombre d\'échéances (mois)';

  @override
  String get liabilities_interest_rate_label => 'Taux d\'intérêt (%)';

  @override
  String get liabilities_loan_type_amortizing => 'Amortissable';

  @override
  String get liabilities_loan_type_in_fine => 'In fine';

  @override
  String get liabilities_monthly_insurance_label => 'Assurance mensuelle (€)';

  @override
  String get liabilities_name_hint => 'Nom (ex: Prêt résidence principale)';

  @override
  String get liabilities_price_total_label => 'Prix total (€)';

  @override
  String get liabilities_start_date_label => 'Date de début';

  @override
  String get navigation_account_activated => 'Compte activé';

  @override
  String get navigation_amounts_hide => 'Masquer les montants';

  @override
  String get navigation_amounts_show => 'Afficher les montants';

  @override
  String get navigation_complete_patrimoine => 'Compléter mon patrimoine';

  @override
  String get navigation_export_download_patrimoine_pdf =>
      'Télécharger mon patrimoine (PDF)';

  @override
  String get navigation_export_tooltip => 'Exporter';

  @override
  String get navigation_export_transactions_csv_json =>
      'Exporter les transactions (JSON/CSV)';

  @override
  String navigation_profile_active_toast_title(Object name) {
    return 'Profil actif: $name';
  }

  @override
  String get navigation_vault_activate_failed_toast_title =>
      'Impossible d\'activer ce coffre-fort';

  @override
  String navigation_vault_active_toast_title(Object name) {
    return 'Coffre-fort actif : $name';
  }

  @override
  String get navigation_vault_fallback_label => 'Coffre-fort';

  @override
  String get navigation_vault_next => 'Coffre-fort suivant';

  @override
  String navigation_vault_next_named(Object name) {
    return 'Coffre-fort suivant : $name';
  }

  @override
  String get navigation_vault_previous => 'Coffre-fort précédent';

  @override
  String navigation_vault_previous_named(Object name) {
    return 'Coffre-fort précédent : $name';
  }

  @override
  String get navigation_vault_switched_toast_subtitle =>
      'Basculé depuis le sélecteur de compte';

  @override
  String notifications_crypto_alert_24h(String symbol, String change) {
    return '$symbol $change % sur 24h';
  }

  @override
  String notifications_crypto_price_line(String name, String price) {
    return '$name · $price €';
  }

  @override
  String get notifications_empty => 'Aucune actualité pour le moment.';

  @override
  String notifications_news_publisher_line(String publisher, String time) {
    return '$publisher · $time';
  }

  @override
  String notifications_relative_days(int days) {
    return 'il y a $days j';
  }

  @override
  String notifications_relative_hours(int hours) {
    return 'il y a $hours h';
  }

  @override
  String notifications_relative_minutes(int minutes) {
    return 'il y a $minutes min';
  }

  @override
  String get notifications_relative_now => 'à l\'instant';

  @override
  String get notifications_title => 'Actualités';

  @override
  String onboarding_change_folder_failed(String error) {
    return 'Impossible de changer de dossier : $error';
  }

  @override
  String get onboarding_change_vault_folder =>
      'Changer de dossier du coffre-fort';

  @override
  String get onboarding_choose_password => 'Choisis un mot de passe.';

  @override
  String get onboarding_confirm_new_password =>
      'Confirmer le nouveau mot de passe';

  @override
  String onboarding_create_folder_failed(String error) {
    return 'Impossible de créer le dossier de données : $error';
  }

  @override
  String get onboarding_creating => 'Création...';

  @override
  String get onboarding_description =>
      'Choisis où seront stockées tes données. Tu peux commencer en local et déplacer ce dossier vers un service cloud (iCloud, Google Drive, Dropbox...) plus tard.';

  @override
  String get onboarding_forgot_password => 'Mot de passe oublié ?';

  @override
  String get onboarding_migration_interrupted_continue =>
      'J\'ai compris, continuer quand même';

  @override
  String get onboarding_migration_interrupted_description =>
      'Une opération de chiffrement ou déchiffrement de ce coffre-fort a été interrompue avant sa fin (l\'app a peut-être été fermée pendant l\'opération). Certains fichiers privés peuvent être restés dans un ancien état pendant que d\'autres sont déjà à jour.';

  @override
  String get onboarding_migration_interrupted_recommendation =>
      'Recommandé : recommence l\'opération depuis les Réglages (Activer/Désactiver le chiffrement) une fois averti — elle remettra tous les fichiers dans le même état. Si un fichier précis refuse ensuite de se charger, ce sera le signe qu\'il faut le restaurer depuis une sauvegarde.';

  @override
  String get onboarding_migration_interrupted_title => 'Chiffrement interrompu';

  @override
  String get onboarding_new_password => 'Nouveau mot de passe';

  @override
  String get onboarding_password => 'Mot de passe';

  @override
  String get onboarding_password_incorrect => 'Mot de passe incorrect.';

  @override
  String get onboarding_passwords_mismatch =>
      'Les deux mots de passe ne correspondent pas.';

  @override
  String get onboarding_pick_location => 'Choisir un emplacement';

  @override
  String get onboarding_recovery_description =>
      'Saisis la clé de récupération que tu as reçue à l\'activation du chiffrement.';

  @override
  String get onboarding_recovery_key_hint =>
      'Clé de récupération (ex. XXXX-XXXX-XXXX-XXXX)';

  @override
  String get onboarding_recovery_key_incorrect =>
      'Clé de récupération incorrecte.';

  @override
  String get onboarding_recovery_new_password_description =>
      'Ta clé de récupération est valide. Choisis un nouveau mot de passe pour ce coffre-fort.';

  @override
  String get onboarding_recovery_new_password_title => 'Nouveau mot de passe';

  @override
  String get onboarding_recovery_saving => 'Enregistrement...';

  @override
  String get onboarding_recovery_set_and_unlock => 'Définir et déverrouiller';

  @override
  String get onboarding_recovery_title => 'Récupération du coffre-fort';

  @override
  String get onboarding_recovery_validate_key => 'Valider la clé';

  @override
  String get onboarding_recovery_verifying => 'Vérification...';

  @override
  String get onboarding_selecting => 'Sélection en cours...';

  @override
  String get onboarding_unlock => 'Déverrouiller';

  @override
  String get onboarding_unlock_description =>
      'Ce coffre-fort est chiffré. Saisis ton mot de passe pour accéder à tes données.';

  @override
  String get onboarding_unlocking => 'Déverrouillage...';

  @override
  String get onboarding_vault_kind_prompt => 'Ce coffre-fort est...';

  @override
  String get onboarding_welcome_title => 'Bienvenue sur Opime';

  @override
  String patrimoine_export_failed_subtitle(String error) {
    return 'Le PDF n\'a pas pu être généré ou enregistré : $error';
  }

  @override
  String get patrimoine_export_generate_pdf => 'Générer le PDF';

  @override
  String get patrimoine_export_save_dialog_title =>
      'Enregistrer le patrimoine (PDF)';

  @override
  String get patrimoine_export_subtitle =>
      'Sélectionnez les actifs et passifs à inclure dans le PDF.';

  @override
  String patrimoine_export_success_subtitle(String path) {
    return 'Le PDF a été enregistré : $path';
  }

  @override
  String get patrimoine_export_title => 'Télécharger mon patrimoine';

  @override
  String get real_estate_add_document_title => 'Ajouter un document';

  @override
  String get real_estate_add_rent_period_button => 'Ajouter une période';

  @override
  String get real_estate_add_work_item_button => 'Ajouter un poste';

  @override
  String get real_estate_add_work_item_title => 'Ajouter un poste de travaux';

  @override
  String get real_estate_amount_due_label => 'Montant dû (loyer + charges)';

  @override
  String get real_estate_amount_received_label => 'Montant perçu';

  @override
  String get real_estate_annual_charges_not_tracked_note =>
      'Charges annuelles (taxe foncière, assurance, gestion...) pas encore suivies : le rendement net est identique au brut.';

  @override
  String get real_estate_annual_rental_income_label => 'Revenu locatif annuel';

  @override
  String get real_estate_cashflow_no_loan_note =>
      'Sans prêt lié (voir ci-dessus) : cash-flow calculé achat comptant, sans mensualité de crédit.';

  @override
  String real_estate_cashflow_with_loan_note(String amount) {
    return 'Mensualité de crédit déduite : $amount.';
  }

  @override
  String get real_estate_continue_button => 'Continuer';

  @override
  String get real_estate_create_mortgage_loan => 'Créer un prêt immobilier';

  @override
  String get real_estate_create_work_loan => 'Créer un crédit travaux';

  @override
  String get real_estate_delete_document_message =>
      'Le fichier sera définitivement supprimé du coffre-fort.';

  @override
  String real_estate_delete_document_title(String fileName) {
    return 'Supprimer \"$fileName\" ?';
  }

  @override
  String real_estate_delete_rent_period_message(String period) {
    return 'La période $period sera définitivement retirée de l\'historique des loyers.';
  }

  @override
  String get real_estate_delete_rent_period_title =>
      'Supprimer cette période ?';

  @override
  String get real_estate_delete_work_item_message =>
      'Ce poste de travaux sera définitivement retiré.';

  @override
  String real_estate_delete_work_item_title(String label) {
    return 'Supprimer \"$label\" ?';
  }

  @override
  String get real_estate_document_category_invoice => 'Facture';

  @override
  String get real_estate_document_category_other => 'Autre';

  @override
  String get real_estate_document_category_photo => 'Photo';

  @override
  String get real_estate_document_category_plan => 'Plan';

  @override
  String get real_estate_document_category_receipt => 'Quittance';

  @override
  String get real_estate_document_name_hint => 'Nom du document (optionnel)';

  @override
  String real_estate_documents_filter_all(int count) {
    return 'Tous ($count)';
  }

  @override
  String get real_estate_documents_title => 'Documents';

  @override
  String get real_estate_gross_yield_label => 'Rendement brut';

  @override
  String get real_estate_link_existing_loan => 'Lier un crédit existant';

  @override
  String real_estate_linked_loan_summary(
    String name,
    String type,
    String balance,
  ) {
    return '$name · $type · $balance';
  }

  @override
  String real_estate_mark_period_paid_title(String period) {
    return 'Marquer $period payé';
  }

  @override
  String get real_estate_month_label => 'Mois';

  @override
  String real_estate_monthly_cashflow_label(String amount) {
    return 'Cash-flow mensuel : $amount';
  }

  @override
  String get real_estate_net_yield_label => 'Rendement net';

  @override
  String get real_estate_no_documents_yet => 'Aucun document pour l\'instant.';

  @override
  String get real_estate_no_rent_periods_yet =>
      'Aucun loyer suivi pour l\'instant.';

  @override
  String get real_estate_no_work_items_yet =>
      'Aucun poste de travaux pour l\'instant.';

  @override
  String get real_estate_not_self_financed => 'Non autofinancé';

  @override
  String get real_estate_note_optional_label => 'Note (facultative)';

  @override
  String get real_estate_payment_date_label => 'Date de paiement';

  @override
  String get real_estate_pricing_address_search_placeholder =>
      'Rechercher une adresse...';

  @override
  String get real_estate_pricing_heatmap_loading_communes =>
      'Chargement des communes visibles...';

  @override
  String real_estate_pricing_heatmap_loading_department_prices(
    int loaded,
    int total,
  ) {
    return 'Chargement des prix par département : $loaded / $total (mis en cache, la prochaine ouverture sera instantanée)';
  }

  @override
  String get real_estate_pricing_heatmap_loading_grid =>
      'Chargement de la grille fine...';

  @override
  String real_estate_pricing_heatmap_neighborhood_tooltip_title(int size) {
    return 'Quartier (~$size m)';
  }

  @override
  String get real_estate_pricing_heatmap_no_data => 'Pas de donnée';

  @override
  String get real_estate_pricing_heatmap_rent_commune_only =>
      'Le loyer n\'est disponible qu\'à l\'échelle de la commune (granularité native de la source).';

  @override
  String real_estate_pricing_heatmap_sale_count(int count) {
    return '$count vente(s)';
  }

  @override
  String get real_estate_profitability_no_rent_hint =>
      'Ajoutez des loyers (onglet Loyers) pour calculer la rentabilité de ce bien.';

  @override
  String get real_estate_rent_paid => 'Payé';

  @override
  String get real_estate_rent_periods_title => 'Loyers';

  @override
  String get real_estate_rent_unpaid => 'Impayé';

  @override
  String get real_estate_self_financed => 'Autofinancé';

  @override
  String get real_estate_tenant_optional_label => 'Locataire (facultatif)';

  @override
  String get real_estate_total_project_cost_label => 'Coût total du projet';

  @override
  String get real_estate_work_category_electrical => 'Électricité';

  @override
  String get real_estate_work_category_furniture => 'Mobilier';

  @override
  String get real_estate_work_category_other => 'Autre';

  @override
  String get real_estate_work_category_paint => 'Peinture';

  @override
  String get real_estate_work_category_plumbing => 'Plomberie';

  @override
  String get real_estate_work_category_structural => 'Gros œuvre';

  @override
  String get real_estate_work_item_amount_label => 'Montant';

  @override
  String get real_estate_work_item_category_optional_label =>
      'Catégorie (facultative)';

  @override
  String get real_estate_work_item_label_field => 'Libellé';

  @override
  String get real_estate_work_item_label_hint => 'Ex : Réfection toiture';

  @override
  String real_estate_work_items_included_note(String amount) {
    return 'Dont $amount de travaux (onglet Travaux).';
  }

  @override
  String get real_estate_work_items_title => 'Travaux';

  @override
  String real_estate_work_items_total_label(String amount) {
    return 'Total : $amount';
  }

  @override
  String get search_category_enveloppe => 'Enveloppes';

  @override
  String get search_category_fondamentaux => 'Fondamentaux';

  @override
  String get search_category_formation => 'Formation';

  @override
  String get search_category_page => 'Pages';

  @override
  String get search_category_patrimoine => 'Patrimoine';

  @override
  String get search_category_vocabulaire => 'Vocabulaire';

  @override
  String get search_no_results => 'Aucun résultat';

  @override
  String get search_placeholder => 'Rechercher dans Opime...';

  @override
  String get settings_encryption_confirm_password =>
      'Confirmer le mot de passe';

  @override
  String get settings_encryption_continue => 'Continuer';

  @override
  String get settings_encryption_dont_close_app =>
      'Ne ferme pas l\'application pendant cette opération (la fermeture de la fenêtre est bloquée le temps qu\'elle se termine).';

  @override
  String get settings_encryption_enable_description =>
      'Choisis un mot de passe pour chiffrer les données privées de ce coffre-fort (comptes, budget, passifs, projets, notes de stratégie, simulations). Il te sera redemandé à chaque lancement de l\'app.';

  @override
  String get settings_encryption_encrypting_progress_label =>
      'Chiffrement des données en cours...';

  @override
  String settings_encryption_files_progress(int done, int total) {
    return '$done / $total fichier(s)';
  }

  @override
  String get settings_encryption_preparing => 'Préparation...';

  @override
  String get settings_encryption_recovery_key_confirmed_checkbox =>
      'J\'ai noté cette clé en lieu sûr';

  @override
  String get settings_encryption_recovery_key_description =>
      'Note-la en lieu sûr (gestionnaire de mots de passe, papier...). Elle permet de redéfinir ton mot de passe si tu l\'oublies — sans elle, tes données sont définitivement perdues. Elle ne sera plus jamais affichée.';

  @override
  String get settings_encryption_recovery_key_title => 'Ta clé de récupération';

  @override
  String get settings_tax_abattement_conjoint_label => 'Conjoint/PACS (€)';

  @override
  String get settings_tax_abattement_enfant_label => 'Enfant (€)';

  @override
  String get settings_tax_abattement_petit_enfant_label => 'Petit-enfant (€)';

  @override
  String get settings_tax_abattements_title => 'Abattements';

  @override
  String get settings_tax_bareme_epoux_title =>
      'Barème entre époux ou partenaires de PACS';

  @override
  String get settings_tax_bareme_ligne_directe_title =>
      'Barème en ligne directe (parent/enfant)';

  @override
  String get settings_tax_bracket_beyond => 'Au-delà';

  @override
  String get settings_tax_bracket_nue_propriete_percent => 'Nue-propriété (%)';

  @override
  String get settings_tax_bracket_rate_percent => 'Taux (%)';

  @override
  String get settings_tax_bracket_upto_eur => 'Jusqu\'à (€)';

  @override
  String get settings_tax_bracket_upto_years => 'Jusqu\'à (ans)';

  @override
  String get settings_tax_demembrement_description =>
      'Barème fiscal de l\'usufruit selon l\'âge de l\'usufruitier (article 669 CGI) — voir la page Simulation → Transmission, onglet Démembrement.';

  @override
  String get settings_tax_demembrement_title =>
      'Démembrement (usufruit / nue-propriété)';

  @override
  String get settings_tax_donation_description =>
      'Barèmes des droits de mutation à titre gratuit (article 777 CGI) et abattements par lien de parenté — voir la page Simulation → Transmission, onglets Démembrement/Donation/Succession.';

  @override
  String get settings_tax_donation_title => 'Donation et succession';

  @override
  String get settings_tax_ifi_description =>
      'Barème par tranches de patrimoine immobilier net (article 977 CGI) et seuil en-dessous duquel l\'IFI n\'est pas dû du tout.';

  @override
  String get settings_tax_ifi_threshold_label =>
      'Seuil d\'imposition (€) — exonération totale en-dessous';

  @override
  String get settings_tax_ifi_title => 'IFI (impôt sur la fortune immobilière)';

  @override
  String get settings_tax_ir_description =>
      'Barème progressif par part de quotient familial (article 197 CGI) — voir la page Simulation → Fiscalité, onglet IR.';

  @override
  String get settings_tax_ir_title => 'Impôt sur le revenu';

  @override
  String get settings_tax_page_description =>
      'Barèmes, seuils et abattements utilisés par les simulateurs (impôt sur le revenu, IFI, démembrement, donation et succession). Modifie une valeur ici si l\'État la révise, sans attendre une mise à jour du logiciel — chacune peut être réinitialisée individuellement à sa référence légale connue via l\'icône ↺ qui apparaît à côté d\'une valeur modifiée.';

  @override
  String get settings_tax_pfu_description =>
      '\"Flat tax\" sur les revenus de capitaux mobiliers et plus-values mobilières, décomposée en sa part IR et sa part prélèvements sociaux — l\'État peut réviser l\'une sans l\'autre (ex : PS passés de 15,5 % à 17,2 % en 2018, puis à 18,6 % début 2026, sans toucher au taux d\'IR). Valeurs de référence uniquement pour l\'instant : aucun simulateur de l\'app ne les utilise encore dans un calcul.';

  @override
  String get settings_tax_pfu_ir_label => 'Part IR (%)';

  @override
  String get settings_tax_pfu_ps_label => 'Part prélèvements sociaux (%)';

  @override
  String get settings_tax_pfu_title => 'PFU (prélèvement forfaitaire unique)';

  @override
  String get settings_tax_reset_to_legal_value =>
      'Réinitialiser à la valeur légale';

  @override
  String get simulations_loan_application_fees_label => 'Frais de dossier';

  @override
  String simulations_loan_capital_repaid_at_maturity(String amount) {
    return 'Capital remboursé en une fois à l\'échéance : $amount';
  }

  @override
  String get simulations_loan_chart_average_monthly_payment =>
      'mensualité moyenne';

  @override
  String get simulations_loan_chart_capital => 'Capital';

  @override
  String get simulations_loan_chart_insurance => 'Assurance';

  @override
  String get simulations_loan_chart_interest => 'Intérêts';

  @override
  String get simulations_loan_chart_today => 'Aujourd\'hui';

  @override
  String simulations_loan_chart_year_label(int year) {
    return 'Année $year';
  }

  @override
  String get simulations_loan_deferral_duration_label => 'Durée du différé';

  @override
  String get simulations_loan_deferral_label => 'Différé de remboursement';

  @override
  String get simulations_loan_deferral_partial => 'Franchise partielle';

  @override
  String get simulations_loan_deferral_partial_explanation =>
      'Seuls les intérêts sont payés pendant le différé, le capital ne bouge pas.';

  @override
  String get simulations_loan_deferral_total => 'Franchise totale';

  @override
  String get simulations_loan_deferral_total_explanation =>
      'Aucun paiement pendant le différé, les intérêts s\'ajoutent au capital restant dû.';

  @override
  String simulations_loan_derived_borrowed_amount(String amount) {
    return 'Montant emprunté (dérivé) : $amount';
  }

  @override
  String get simulations_loan_disclaimer =>
      'Simulation de prêt indicative : les résultats reposent sur des hypothèses simplifiées (taux constants, assurance linéaire, frais fixes). Les conditions bancaires réelles, garanties et clauses contractuelles peuvent modifier le coût total du crédit.';

  @override
  String get simulations_loan_down_payment_label => 'Apport';

  @override
  String simulations_loan_during_deferral_monthly_payment(String amount) {
    return 'Pendant le différé : $amount/mois';
  }

  @override
  String get simulations_loan_guarantee_fees_label => 'Frais de garantie';

  @override
  String get simulations_loan_including_insurance => 'Dont assurance';

  @override
  String get simulations_loan_interest_rate_label => 'Taux d\'intérêt';

  @override
  String get simulations_loan_monthly_insurance_label => 'Assurance mensuelle';

  @override
  String get simulations_loan_monthly_payments_label => 'Mensualités';

  @override
  String get simulations_loan_per_month_suffix => 'mois';

  @override
  String get simulations_loan_project_amount_label => 'Montant du projet';

  @override
  String get simulations_loan_repayment_duration_label =>
      'Durée de remboursement';

  @override
  String get simulations_loan_reset_parameters =>
      'Réinitialiser les paramètres';

  @override
  String get simulations_loan_suffix_eur_per_month => '€/mois';

  @override
  String get simulations_loan_suffix_months => 'mois';

  @override
  String get simulations_loan_suffix_years => 'ans';

  @override
  String get simulations_loan_summary_monthly_payment_is =>
      ', votre mensualité s\'élève à ';

  @override
  String get simulations_loan_summary_over => ' sur ';

  @override
  String get simulations_loan_summary_prefix => 'Pour un emprunt de ';

  @override
  String get simulations_loan_total_cost_incl_fees_label =>
      'Coût total (frais inclus)';

  @override
  String get simulations_loan_total_credit_cost_label => 'Coût total du crédit';

  @override
  String get simulations_loan_type_amortizing => 'Amortissable';

  @override
  String get simulations_loan_type_infine => 'In fine';

  @override
  String get simulations_loan_type_label => 'Type de crédit';

  @override
  String get simulations_real_estate_tab_estimation => 'Estimation';

  @override
  String get simulations_real_estate_tab_loan => 'Prêt';

  @override
  String get simulations_real_estate_tab_scoring => 'Scoring';

  @override
  String get simulations_scoring_age_label => 'Âge';

  @override
  String get simulations_scoring_bank_history_label => 'Historique bancaire';

  @override
  String get simulations_scoring_bank_history_none_1y =>
      'Aucun incident (< 1 an)';

  @override
  String get simulations_scoring_bank_history_none_3y =>
      'Aucun incident (≥ 3 ans)';

  @override
  String get simulations_scoring_bank_history_none_6m =>
      'Aucun incident (< 6 mois)';

  @override
  String get simulations_scoring_bank_history_one_6m => '1 incident (< 6 mois)';

  @override
  String get simulations_scoring_bank_history_several_6m =>
      'Plusieurs incidents (< 6 mois)';

  @override
  String get simulations_scoring_debt_ratio_label => 'Taux d\'endettement';

  @override
  String get simulations_scoring_disclaimer =>
      'Estimation pédagogique et indicative : la grille de notation utilisée ici est une simplification courante des critères bancaires classiques, pas le barème d\'un établissement précis. Le scoring réel d\'une banque tient compte de bien d\'autres éléments (garanties, patrimoine, politique interne du moment...).';

  @override
  String get simulations_scoring_disposable_income_label => 'Revenu disponible';

  @override
  String simulations_scoring_disposable_income_value(int value) {
    return '$value € / an';
  }

  @override
  String simulations_scoring_duration_years_fractional(String years) {
    return '$years ans';
  }

  @override
  String get simulations_scoring_household_monthly_income_label =>
      'Revenus mensuels du foyer';

  @override
  String get simulations_scoring_income_charges_section_label =>
      'Revenus & charges';

  @override
  String get simulations_scoring_income_seniority_label =>
      'Ancienneté des revenus actuels';

  @override
  String get simulations_scoring_income_stability_label =>
      'Stabilité des revenus';

  @override
  String get simulations_scoring_monthly_expenses_label =>
      'Charges mensuelles (hors prêt immo)';

  @override
  String get simulations_scoring_monthly_savings_label => 'Épargne mensuelle';

  @override
  String get simulations_scoring_mortgage_payment_label =>
      'Mensualité du prêt immobilier';

  @override
  String simulations_scoring_overall_profile_label(String tier) {
    return 'Profil $tier';
  }

  @override
  String get simulations_scoring_prefilled_from_loan_tab =>
      'Pré-remplie depuis l\'onglet Prêt tant que non modifiée ici.';

  @override
  String get simulations_scoring_profession_employee => 'Salarié';

  @override
  String get simulations_scoring_profession_executive => 'Cadre';

  @override
  String get simulations_scoring_profession_executive_senior =>
      'Dirigeant / Cadre supérieur';

  @override
  String get simulations_scoring_profession_label => 'Profession';

  @override
  String get simulations_scoring_profession_unemployed => 'Chômeur';

  @override
  String get simulations_scoring_profession_worker => 'Ouvrier';

  @override
  String get simulations_scoring_profile_section_label => 'Profil';

  @override
  String get simulations_scoring_savings_effort_label => 'Effort d\'épargne';

  @override
  String get simulations_scoring_suffix_shares => 'parts';

  @override
  String get simulations_scoring_tax_shares_label => 'Parts fiscales';

  @override
  String get simulations_scoring_tier_average => 'Moyen';

  @override
  String get simulations_scoring_tier_critical => 'Critique';

  @override
  String get simulations_scoring_tier_excellent => 'Excellent';

  @override
  String get simulations_scoring_tier_good => 'Bon';

  @override
  String get simulations_scoring_tier_poor => 'Mauvais';

  @override
  String simulations_scoring_total_points(int points) {
    return '$points / 35 points';
  }

  @override
  String get transactions_export_deselect_all => 'Tout désélectionner';

  @override
  String get transactions_export_empty =>
      'Aucune transaction à exporter pour l\'instant.';

  @override
  String transactions_export_failed_subtitle(String error) {
    return 'Le fichier n\'a pas pu être généré ou enregistré : $error';
  }

  @override
  String get transactions_export_failed_title => 'Échec de l\'export';

  @override
  String get transactions_export_save_dialog_title =>
      'Enregistrer les transactions';

  @override
  String get transactions_export_select_all => 'Tout sélectionner';

  @override
  String get transactions_export_subtitle =>
      'Sélectionnez les comptes à inclure.';

  @override
  String transactions_export_success_subtitle(String path) {
    return 'Le fichier a été enregistré : $path';
  }

  @override
  String get transactions_export_success_title => 'Export réussi';

  @override
  String get transactions_export_title => 'Exporter mes transactions';

  @override
  String transactions_export_transaction_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return '$_temp0';
  }

  @override
  String updates_banner_new_version(String version) {
    return 'Une nouvelle version d\'Opime est disponible ($version).';
  }

  @override
  String get nav_assets_actions_funds => 'Actions & Fonds';

  @override
  String get nav_assets_private_equity => 'Private Equity';

  @override
  String get nav_assets_real_estate => 'Immobilier';

  @override
  String get nav_assets_crypto => 'Crypto';

  @override
  String get nav_assets_precious_metals => 'Métaux précieux';

  @override
  String get nav_assets_savings => 'Épargne';

  @override
  String get nav_assets_other => 'Autres';

  @override
  String get nav_liabilities_loans => 'Emprunts';

  @override
  String get nav_liabilities_mortgages => 'Crédits immobiliers';

  @override
  String get nav_investment => 'Fondamentaux';

  @override
  String get nav_invest_why => 'Pourquoi investir ?';

  @override
  String get nav_invest_inflation => 'L\'inflation';

  @override
  String get nav_invest_risk => 'Le risque';

  @override
  String get nav_invest_diversification => 'Diversification';

  @override
  String get nav_invest_etf => 'Les ETF';

  @override
  String get nav_invest_fees => 'Les frais';

  @override
  String get nav_invest_taxation => 'La fiscalité';

  @override
  String get nav_invest_pyramid => 'Pyramide de l\'investissement';

  @override
  String get nav_invest_allocation => 'Allocation stratégique/dynamique';

  @override
  String get nav_invest_long_term => 'Le temps long';

  @override
  String get nav_envelopes => 'Enveloppes';

  @override
  String get nav_envelope_current_account => 'Compte courant';

  @override
  String get nav_envelope_livret_a => 'Livret A';

  @override
  String get nav_envelope_ldds => 'LDDS';

  @override
  String get nav_envelope_lep => 'LEP';

  @override
  String get nav_envelope_pel => 'PEL';

  @override
  String get nav_envelope_cto => 'CTO';

  @override
  String get nav_envelope_pea => 'PEA';

  @override
  String get nav_envelope_life_insurance => 'Assurance-vie';

  @override
  String get nav_envelope_capitalization_contract =>
      'Contrat de capitalisation';

  @override
  String get nav_envelope_pee_peg => 'PEE / PEG';

  @override
  String get nav_envelope_per => 'PER';

  @override
  String get nav_training => 'Formation';

  @override
  String get nav_training_stock_market => 'Bourse';

  @override
  String get nav_training_precious_metals => 'Métaux précieux';

  @override
  String get nav_training_crypto => 'Crypto';

  @override
  String get nav_training_real_estate => 'Immobilier';

  @override
  String get nav_training_wealth_structuring => 'Structuration patrimoniale';

  @override
  String get simulations_wealth_tab_compound_interest => 'Intérêts composés';

  @override
  String get simulations_wealth_tab_deterministic_compound_interest =>
      'Déterministe (Intérêts composés)';

  @override
  String get simulations_wealth_tab_monte_carlo => 'Monte-Carlo';

  @override
  String get simulations_wealth_tab_stochastic_monte_carlo =>
      'Stochastique (Monte-Carlo)';

  @override
  String get simulations_wealth_simple_disclaimer =>
      'Projection déterministe indicative fondée sur des rendements constants et une fiscalité simplifiée. Les valeurs « pouvoir d\'achat actuel » actualisent le résultat nominal avec le taux d\'inflation renseigné (valeur réelle = valeur nominale ÷ (1 + inflation)^années). Les marchés, frais, impôts réels et aléas de vie peuvent modifier significativement les résultats.';

  @override
  String get simulations_wealth_monte_carlo_disclaimer =>
      'Simulation Monte-Carlo indicative: les distributions retenues et hypothèses de volatilité restent simplifiées. Les percentiles ne constituent ni une garantie de performance ni une recommandation d\'investissement.';

  @override
  String get simulations_wealth_current_assets => 'Patrimoine actuel';

  @override
  String get simulations_wealth_initial_asset_allocation =>
      'Répartition de votre patrimoine initial';

  @override
  String get simulations_wealth_stock => 'Bourse';

  @override
  String get simulations_wealth_other => 'Autre';

  @override
  String get simulations_wealth_monthly_investments =>
      'Investissements mensuels';

  @override
  String get simulations_wealth_investment_allocation =>
      'Répartition des investissements';

  @override
  String get simulations_wealth_savings_years => 'Nombre d\'années d\'épargne';

  @override
  String get simulations_wealth_stock_return => 'Rendement bourse';

  @override
  String get simulations_wealth_other_return => 'Rendement autre';

  @override
  String get simulations_wealth_stock_tax => 'Imposition bourse';

  @override
  String get simulations_wealth_other_tax => 'Imposition autre';

  @override
  String get simulations_wealth_withdrawal_rate => 'Taux de retrait';

  @override
  String get simulations_wealth_inflation_rate => 'Taux d\'inflation';

  @override
  String get simulations_wealth_reset_parameters =>
      'Réinitialiser les paramètres';

  @override
  String simulations_wealth_net_value_in_n_years(int count) {
    return 'Valeur nette dans $count ans';
  }

  @override
  String get simulations_wealth_passive_income_prefix =>
      'soit un revenu passif d\'environ ';

  @override
  String get simulations_wealth_initial_assets => 'Patrimoine initial';

  @override
  String get simulations_wealth_contributions => 'Versements';

  @override
  String get simulations_wealth_net_interest => 'Intérêts nets';

  @override
  String get simulations_wealth_stat_future_value => 'Valeur future';

  @override
  String get simulations_wealth_stat_included_capital_gains =>
      'Dont plus-value';

  @override
  String get simulations_wealth_stat_net_value => 'Valeur nette';

  @override
  String get simulations_wealth_stat_monthly_income => 'Revenu mensuel';

  @override
  String get simulations_wealth_stat_net_value_purchasing_power =>
      'Valeur nette (pouvoir d\'achat actuel)';

  @override
  String get simulations_wealth_stat_monthly_income_purchasing_power =>
      'Revenu mensuel (pouvoir d\'achat actuel)';

  @override
  String get simulations_wealth_chart_today => 'Aujourd\'hui';

  @override
  String simulations_wealth_chart_in_n_years(int count) {
    return 'Dans $count ans';
  }

  @override
  String simulations_wealth_chart_n_years(int count) {
    return '$count ans';
  }

  @override
  String get simulations_wealth_avg_stock_return => 'Rendement moyen bourse';

  @override
  String get simulations_wealth_stock_std_dev => 'Écart-type bourse';

  @override
  String get simulations_wealth_avg_other_return => 'Rendement moyen autre';

  @override
  String get simulations_wealth_other_std_dev => 'Écart-type autre';

  @override
  String get simulations_wealth_number_of_simulations =>
      'Nombre de simulations';

  @override
  String simulations_wealth_median_net_value_in_n_years(int count) {
    return 'Valeur nette médiane dans $count ans';
  }

  @override
  String get simulations_wealth_median_passive_income_prefix =>
      'soit un revenu passif médian d\'environ ';

  @override
  String simulations_wealth_between_p10_and_p90(String p10, String p90) {
    return 'Entre $p10 et $p90 selon les scénarios (10e-90e percentile)';
  }

  @override
  String get simulations_wealth_median_net_interest =>
      'Médiane (intérêts nets)';

  @override
  String get simulations_wealth_stat_median_future_value =>
      'Valeur future médiane';

  @override
  String get simulations_wealth_stat_median_included_capital_gains =>
      'Dont plus-value médiane';

  @override
  String get simulations_wealth_stat_median_net_value => 'Valeur nette médiane';

  @override
  String get simulations_wealth_stat_median_monthly_income =>
      'Revenu mensuel médian';

  @override
  String get simulations_wealth_median_label => 'Médiane';

  @override
  String get simulations_wealth_90th_percentile => '90e percentile';

  @override
  String get simulations_wealth_10th_percentile => '10e percentile';

  @override
  String get simulations_transmission_demembrement => 'Démembrement';

  @override
  String get simulations_transmission_donation => 'Donation';

  @override
  String get simulations_transmission_heritage => 'Héritage';

  @override
  String get simulations_transmission_value_full_property =>
      'Valeur en pleine propriété';

  @override
  String get simulations_transmission_usufruitier_age =>
      'Âge de l\'usufruitier';

  @override
  String get simulations_transmission_number_beneficiary_children =>
      'Nombre d\'enfants bénéficiaires';

  @override
  String get simulations_transmission_abatement_per_child_remaining =>
      'Abattement par enfant (restant)';

  @override
  String get simulations_transmission_reset_parameters =>
      'Réinitialiser les paramètres';

  @override
  String get simulations_transmission_projection_demembrement =>
      'Projection des droits en démembrement';

  @override
  String get simulations_transmission_hypothesis_2026_nue =>
      'Hypothèse 2026 : nue-propriété ';

  @override
  String get simulations_transmission_usufruit_separator => ' / usufruit ';

  @override
  String get simulations_transmission_scenario_comparison =>
      'Comparaison des scénarios';

  @override
  String get simulations_transmission_full_property_rights =>
      'Droits pleine propriété';

  @override
  String get simulations_transmission_demembrement_rights =>
      'Droits démembrement';

  @override
  String get simulations_transmission_potential_savings =>
      'Économie potentielle';

  @override
  String get simulations_transmission_np_value => 'Valeur NP';

  @override
  String get simulations_transmission_np_taxable_per_child =>
      'Taxable NP / enfant';

  @override
  String get simulations_transmission_np_rights_per_child =>
      'Droits NP / enfant';

  @override
  String get simulations_transmission_full_property_rights_if =>
      'Droits si pleine propriété';

  @override
  String get simulations_transmission_demembrement_rights_detail =>
      'Droits en démembrement';

  @override
  String get simulations_transmission_donation_amount =>
      'Montant de la donation';

  @override
  String get simulations_transmission_number_beneficiaries =>
      'Nombre de bénéficiaires';

  @override
  String get simulations_transmission_donor_donee_link =>
      'Lien donateur / donataire';

  @override
  String get simulations_transmission_child => 'Enfant';

  @override
  String get simulations_transmission_grandchild => 'Petit-enfant';

  @override
  String get simulations_transmission_spouse_pacs => 'Conjoint/PACS';

  @override
  String simulations_transmission_abatement_per_beneficiary(String amount) {
    return 'Abattement pris en compte : $amount / bénéficiaire';
  }

  @override
  String get simulations_transmission_estimated_donation_rights =>
      'Droits de donation estimés';

  @override
  String get simulations_transmission_effective_rate_prefix => 'Taux effectif ';

  @override
  String get simulations_transmission_effective_rate_suffix =>
      ' sur le montant transmis.';

  @override
  String get simulations_transmission_tax_breakdown => 'Répartition fiscale';

  @override
  String get simulations_transmission_total_amount_transferred =>
      'Montant total transmis';

  @override
  String get simulations_transmission_total_taxable_base =>
      'Base taxable totale';

  @override
  String get simulations_transmission_total_rights => 'Droits totaux';

  @override
  String get simulations_transmission_amount_per_beneficiary =>
      'Montant / bénéficiaire';

  @override
  String get simulations_transmission_taxable_per_beneficiary =>
      'Taxable / bénéficiaire';

  @override
  String get simulations_transmission_rights_per_beneficiary =>
      'Droits / bénéficiaire';

  @override
  String get simulations_transmission_estimated_inheritance_rights =>
      'Droits de succession estimés';

  @override
  String get simulations_transmission_estate_breakdown =>
      'Répartition de la succession';

  @override
  String get simulations_transmission_spouse_exempt_part =>
      'Part conjoint exonérée';

  @override
  String get simulations_transmission_children_mass => 'Masse enfants';

  @override
  String get simulations_transmission_children_total_rights =>
      'Droits totaux enfants';

  @override
  String get simulations_transmission_children_transferred_mass =>
      'Masse transmise aux enfants';

  @override
  String get simulations_transmission_gross_part_per_child =>
      'Part brute / enfant';

  @override
  String get simulations_transmission_taxable_per_child => 'Taxable / enfant';

  @override
  String get simulations_transmission_rights_per_child => 'Droits / enfant';

  @override
  String get simulations_transmission_net_per_child => 'Net / enfant';

  @override
  String get simulations_transmission_surviving_spouse => 'Conjoint survivant';

  @override
  String get simulations_transmission_spouse_share =>
      'Part attribuée au conjoint';

  @override
  String get simulations_transmission_number_inheriting_children =>
      'Nombre d\'enfants héritiers';

  @override
  String get simulations_transmission_net_estate_assets =>
      'Actif net successoral';

  @override
  String get simulations_transmission_abatement_per_child =>
      'Abattement par enfant';

  @override
  String get simulations_transmission_disclaimer_demembrement =>
      'Barème de valorisation usufruit/nue-propriété selon l\'article 669 CGI (référentiel 2026). Simulation indicative, hors clauses civiles spécifiques, réserve/usufruit successif et optimisation notariale personnalisée.';

  @override
  String get simulations_transmission_disclaimer_donation =>
      'Barèmes simplifiés de droits de donation 2026. Abattements simulés par lien de parenté, hors dons familiaux de sommes d\'argent, rapport fiscal, réductions spécifiques ou passif déductible.';

  @override
  String get simulations_transmission_disclaimer_heritage =>
      'Référentiel succession 2026 simplifié : conjoint/PACS exonéré, barème ligne directe pour enfants. Ne tient pas compte des options civiles détaillées (usufruit légal du conjoint, quotité disponible, testament, assurance-vie).';

  @override
  String get simulations_estimation_property_address => 'Adresse du bien';

  @override
  String get simulations_estimation_price_per_sqm => 'Prix au m²';

  @override
  String get simulations_estimation_rent_per_sqm => 'Loyer au m²';

  @override
  String get simulations_estimation_property_usage => 'Usage du bien';

  @override
  String get simulations_estimation_usage_locatif => 'Investissement locatif';

  @override
  String get simulations_estimation_usage_residence =>
      'Résidence principale/secondaire';

  @override
  String get simulations_estimation_property_type => 'Type de bien';

  @override
  String get simulations_estimation_type_maison => 'Maison';

  @override
  String get simulations_estimation_type_appartement => 'Appartement';

  @override
  String get simulations_estimation_field_surface => 'Surface';

  @override
  String get simulations_estimation_field_price_per_sqm =>
      'Prix au m² (corrigeable)';

  @override
  String get simulations_estimation_rental_units => 'Unités locatives';

  @override
  String simulations_estimation_unit_number(int n) {
    return 'Unité $n';
  }

  @override
  String get simulations_estimation_financing => 'Financement';

  @override
  String get simulations_estimation_field_travaux => 'Travaux';

  @override
  String get simulations_estimation_field_frais_notaire => 'Frais de notaire';

  @override
  String get simulations_estimation_field_charges_annuelles =>
      'Charges annuelles (copro, taxe foncière, assurance...)';

  @override
  String get simulations_estimation_cash_purchase =>
      'Achat comptant (sans crédit)';

  @override
  String simulations_estimation_derived_loan_amount(String amount) {
    return 'Montant emprunté (dérivé) : $amount';
  }

  @override
  String simulations_estimation_loan_info(
    String apport,
    String taux,
    int duree,
    String assurance,
  ) {
    return 'Apport $apport, taux $taux % sur $duree ans, assurance $assurance/mois — réglés dans l\'onglet Prêt.';
  }

  @override
  String get simulations_estimation_use_configured_loan =>
      'Utiliser le prêt configuré';

  @override
  String get simulations_estimation_estimated_price => 'Prix estimé du bien';

  @override
  String get simulations_estimation_estimation_in_progress =>
      'Estimation en cours...';

  @override
  String simulations_estimation_comparable_sales_info(
    int sampleSize,
    String scope,
    String years,
  ) {
    return 'Basé sur $sampleSize vente(s) comparable(s) $scope, $years.';
  }

  @override
  String get simulations_estimation_no_comparable_sales =>
      'Aucune vente comparable trouvée — prix à ajuster manuellement.';

  @override
  String get simulations_estimation_rent_estimation_in_progress =>
      'Estimation du loyer en cours...';

  @override
  String get simulations_estimation_estimated_rent_label => 'Loyer estimé : ';

  @override
  String get simulations_estimation_rent_zone_commune => ' (commune)';

  @override
  String get simulations_estimation_rent_zone_expanded => ' (zone élargie)';

  @override
  String get simulations_estimation_gross_rental_income =>
      'Revenu locatif brut';

  @override
  String get simulations_estimation_net_rental_income => 'Revenu locatif net';

  @override
  String get simulations_estimation_loan_payment => 'Mensualité crédit';

  @override
  String get simulations_estimation_project_self_financed =>
      'Projet autofinancé';

  @override
  String get simulations_estimation_project_not_self_financed =>
      'Projet non autofinancé';

  @override
  String simulations_estimation_monthly_cash_flow(String amount) {
    return 'Cash-flow mensuel : $amount';
  }

  @override
  String get simulations_estimation_gross_yield => 'Rendement brut';

  @override
  String get simulations_estimation_net_yield => 'Rendement net';

  @override
  String get simulations_estimation_total_project_cost =>
      'Coût total du projet';

  @override
  String get simulations_estimation_strategy => 'Stratégie';

  @override
  String get simulations_estimation_strategy_long_term => 'Longue durée';

  @override
  String get simulations_estimation_strategy_short_term => 'Courte durée';

  @override
  String get simulations_estimation_strategy_seasonal_mix => 'Mixte saisonnier';

  @override
  String get simulations_estimation_strategy_colocation => 'Colocation';

  @override
  String get simulations_estimation_field_monthly_rent => 'Loyer mensuel (€)';

  @override
  String get simulations_estimation_field_nightly_rate => 'Tarif/nuit (€)';

  @override
  String get simulations_estimation_field_occupancy => 'Occupation (%)';

  @override
  String get simulations_estimation_field_long_term_months =>
      'Mois longue durée';

  @override
  String get simulations_estimation_field_long_term_rent =>
      'Loyer longue durée (€)';

  @override
  String get simulations_estimation_field_short_term_months =>
      'Mois courte durée';

  @override
  String get simulations_estimation_field_summer_nightly_rate =>
      'Tarif/nuit été (€)';

  @override
  String simulations_estimation_room_number(int n) {
    return 'Chambre $n';
  }

  @override
  String get simulations_estimation_add_room => '+ Ajouter une chambre';

  @override
  String get simulations_estimation_unit_default_label => 'Bien entier';

  @override
  String get simulations_estimation_whole_township => '(commune entière)';

  @override
  String simulations_estimation_within_radius(String kilometers) {
    return 'dans un rayon de $kilometers km';
  }

  @override
  String get simulations_estimation_room_default_label => 'Chambre 1';

  @override
  String get budget_manage_recurring_tooltip => 'Lignes récurrentes';

  @override
  String get budget_new_category_placeholder => 'Nouvelle catégorie';

  @override
  String get investments_documents_no_transaction_title => 'Aucune transaction';

  @override
  String get investments_documents_no_transaction_message =>
      'Ajoute d\'abord une transaction pour pouvoir y rattacher un document.';

  @override
  String get investments_documents_link_transaction_label =>
      'Rattacher à quelle transaction ?';

  @override
  String get investments_documents_empty => 'Aucun document pour l\'instant.';

  @override
  String get investments_documents_view_dialog_title =>
      'Documents de la transaction';

  @override
  String investments_documents_view_dialog_subtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents — cliquez pour ouvrir.',
      one: '1 document — cliquez pour ouvrir.',
    );
    return '$_temp0';
  }

  @override
  String budget_recurring_templates_dialog_title(String sectionTitle) {
    return 'Lignes récurrentes — $sectionTitle';
  }

  @override
  String get budget_recurring_templates_dialog_subtitle =>
      'Un point de départ réutilisable, pas une règle vivante : modifier un template ne change pas les lignes déjà ajoutées les mois précédents.';

  @override
  String get budget_recurring_templates_empty =>
      'Aucune ligne récurrente pour l\'instant.';

  @override
  String get budget_recurring_templates_apply_now => 'Appliquer maintenant';

  @override
  String get investments_edit_account_menu_item => 'Modifier le compte';

  @override
  String get investments_delete_account_menu_item => 'Supprimer le compte';

  @override
  String get investments_delete_account_requires_empty_tooltip =>
      'Vide-le d\'abord';

  @override
  String get investments_reinclude_in_net_worth_menu_item =>
      'Réintégrer au patrimoine';

  @override
  String get investments_exclude_from_net_worth_menu_item =>
      'Exclure du patrimoine';

  @override
  String get investments_import_ibkr_statement_menu_item =>
      'Importer un relevé (IBKR)';

  @override
  String get investments_tab_positions => 'Positions';

  @override
  String get investments_tab_transactions => 'Transactions';

  @override
  String get investments_show_all_account_toggle_expanded =>
      'Masquer le reste du compte';

  @override
  String investments_show_all_account_toggle_collapsed(int count) {
    return 'Afficher tout le compte (+$count)';
  }

  @override
  String get projects_new_project => 'Nouveau projet';

  @override
  String get projects_edit_project => 'Modifier le projet';

  @override
  String get projects_name_placeholder =>
      'Nom du projet (ex: Achat résidence principale)';

  @override
  String get projects_description_placeholder => 'Description (facultatif)';

  @override
  String get projects_echeance_placeholder => 'Échéance';

  @override
  String get projects_rendement_placeholder => 'Rendement attendu (% / an)';

  @override
  String get projects_apport_mensuel_placeholder =>
      'Apport mensuel en € (facultatif)';

  @override
  String get projects_montant_cible_placeholder =>
      'Montant cible en € (facultatif)';

  @override
  String get projects_linked_accounts_label => 'Comptes liés';

  @override
  String get projects_linked_liabilities_label => 'Passifs liés';

  @override
  String get projects_dangling_links_warning =>
      '1 lien ou plus ne se résout plus (élément supprimé depuis).';

  @override
  String get projects_no_accounts_available => 'Aucun compte disponible.';

  @override
  String get projects_no_liabilities_available => 'Aucun passif disponible.';

  @override
  String get projects_trajectory_title => 'Trajectoire projetée';

  @override
  String get projects_stat_rendement_attendu => 'Rendement attendu';

  @override
  String get projects_stat_apport_mensuel => 'Apport mensuel';

  @override
  String get projects_stat_temps_restant => 'Temps restant';

  @override
  String get projects_stat_montant_actuel => 'Montant actuel';

  @override
  String get projects_stat_reste_a_atteindre => 'Reste à atteindre';

  @override
  String get projects_linked_accounts_liabilities_title =>
      'Comptes et passifs liés';

  @override
  String get projects_echeance_deadline_passed => 'Échéance dépassée';

  @override
  String get projects_echeance_today => 'Échéance aujourd\'hui';

  @override
  String projects_echeance_in_days(int days) {
    return 'Dans $days jours';
  }

  @override
  String projects_echeance_in_months(int months) {
    return 'Dans $months mois';
  }

  @override
  String projects_echeance_in_years(int years) {
    return 'Dans $years ans';
  }

  @override
  String projects_days_count(int days) {
    return '$days jours';
  }

  @override
  String get projects_on_track_label => 'En bonne voie';

  @override
  String get projects_off_track_label => 'En retard';

  @override
  String get projects_load_error =>
      'Impossible de charger les projets. Vérifiez que le dossier Coffre-fort est accessible.';

  @override
  String get projects_select_or_create => 'Sélectionne ou crée un projet';

  @override
  String get projects_empty => 'Aucun projet';

  @override
  String get simulations_taxation_tab_ir => 'IR';

  @override
  String get simulations_taxation_tab_ifi => 'IFI';

  @override
  String get simulations_taxation_tab_pfu => 'PFU';

  @override
  String get simulations_taxation_ifi_disclaimer =>
      'Simulation IFI indicative basée sur un barème 2026 simplifié, hors dispositifs spécifiques (décote, exonérations particulières, cas de démembrement, plafonnement selon revenus, etc.). Les règles fiscales évoluent régulièrement : vérifiez toujours avec un professionnel avant décision.';

  @override
  String get simulations_taxation_ir_disclaimer =>
      'Simulation d\'impôt sur le revenu indicative avec quotient familial simplifié. Elle n\'intègre pas toutes les situations réelles (charges déductibles, crédits/réductions d\'impôt, revenus spécifiques, plafonnements et règles particulières). Vérifiez le résultat final avec un expert.';

  @override
  String get simulations_taxation_field_ifi_net_worth =>
      'Patrimoine immobilier net';

  @override
  String get simulations_taxation_reset_parameters =>
      'Réinitialiser les paramètres';

  @override
  String get simulations_taxation_ifi_summary_prefix =>
      'Cette année, vous avez un patrimoine immobilier net de ';

  @override
  String get simulations_taxation_ifi_summary_middle =>
      ', induisant un impôt sur la fortune immobilière total de ';

  @override
  String get simulations_taxation_summary_equivalent_suffix =>
      ', soit l\'équivalent de ';

  @override
  String get simulations_taxation_legend_amount => 'Montant';

  @override
  String get simulations_taxation_legend_bracket_max =>
      'Montant max de la tranche';

  @override
  String get simulations_taxation_legend_tax => 'Impôt';

  @override
  String get simulations_taxation_ifi_stat_max_rate =>
      'Taux maximal d\'imposition';

  @override
  String get simulations_taxation_ifi_stat_total_monthly =>
      'IFI (total & mensualisé)';

  @override
  String get simulations_taxation_pfu_field_envelope => 'Enveloppe';

  @override
  String get simulations_taxation_pfu_field_data_source => 'Source des données';

  @override
  String get simulations_taxation_pfu_mode_manual => 'Saisie manuelle';

  @override
  String get simulations_taxation_pfu_mode_existing_account =>
      'Compte existant';

  @override
  String get simulations_taxation_pfu_field_choose_account =>
      'Choisir un compte';

  @override
  String get simulations_taxation_pfu_select_account_placeholder =>
      'Sélectionner…';

  @override
  String simulations_taxation_pfu_no_account_found(String envelope) {
    return 'Aucun compte $envelope trouvé dans le patrimoine.';
  }

  @override
  String get simulations_taxation_pfu_field_opening_date =>
      'Date d\'ouverture du compte';

  @override
  String get simulations_taxation_field_invested_amount => 'Montant investi';

  @override
  String get simulations_taxation_field_current_value => 'Valeur actuelle';

  @override
  String get simulations_taxation_field_withdrawal_amount =>
      'Montant du retrait';

  @override
  String simulations_taxation_pfu_summary_withdrawal_exempt_prefix(
    String envelope,
  ) {
    return 'Retrait $envelope après 5 ans : ';
  }

  @override
  String simulations_taxation_pfu_summary_withdrawal_prefix(String envelope) {
    return 'Retrait $envelope : ';
  }

  @override
  String get simulations_taxation_pfu_summary_tax_exempt => 'exonéré d\'impôts';

  @override
  String get simulations_taxation_pfu_summary_gain_prefix => 'gain de ';

  @override
  String get simulations_taxation_pfu_summary_pfu_tax_prefix =>
      ', impôt PFU de ';

  @override
  String get simulations_taxation_pfu_summary_net_received_prefix =>
      ', net reçu ';

  @override
  String get simulations_taxation_pfu_exempt_message =>
      'Votre retrait est totalement exonéré d\'impôts.';

  @override
  String get simulations_taxation_pfu_exempt_explanation =>
      'Les gains d\'un PEA sont exonérés d\'IR et de PS après 5 ans de détention.';

  @override
  String get simulations_taxation_pfu_stat_unrealized_gain => 'Gain latent';

  @override
  String get simulations_taxation_pfu_stat_taxable_gain => 'Gain imposable';

  @override
  String simulations_taxation_pfu_stat_ir_rate(String rate) {
    return 'IR (PFU $rate%)';
  }

  @override
  String simulations_taxation_pfu_stat_ps_rate(String rate) {
    return 'PS (PFU $rate%)';
  }

  @override
  String get simulations_taxation_pfu_stat_total => 'PFU total';

  @override
  String get simulations_taxation_pfu_stat_net_received => 'Montant net reçu';

  @override
  String get simulations_taxation_pfu_comparison_title =>
      'Comparaison : PFU vs barème progressif';

  @override
  String get simulations_taxation_pfu_stat_bareme_ir => 'Barème IR';

  @override
  String get simulations_taxation_pfu_stat_bareme_ps => 'Barème PS';

  @override
  String get simulations_taxation_pfu_stat_bareme_total => 'Barème total';

  @override
  String get simulations_taxation_pfu_stat_net_after_bareme =>
      'Net après barème';

  @override
  String get simulations_taxation_pfu_wins_label =>
      'Le PFU est plus avantageux';

  @override
  String get simulations_taxation_bareme_wins_label =>
      'Le barème est plus avantageux';

  @override
  String simulations_taxation_pfu_comparison_savings(
    String label,
    String amount,
  ) {
    return '$label ($amount d\'économie)';
  }

  @override
  String get simulations_taxation_pfu_about_title =>
      'À propos du PFU (flat tax)';

  @override
  String get simulations_taxation_pfu_about_body =>
      'Le PFU est un prélèvement forfaitaire unique de 31,4 % (12,8 % IR + 18,6 % PS) sur les plus-values de cession. Pour les PEA, les gains sont exonérés après 5 ans. Pour les Assurance-Vie, un abattement annuel de 4 600 € (9 200 € après 8 ans) s\'applique avant taxation.';

  @override
  String get simulations_taxation_pfu_about_rates_note =>
      'Les taux utilisés proviennent de Réglages → Paramètres fiscaux et peuvent être personnalisés.';

  @override
  String get simulations_taxation_field_taxable_income =>
      'Revenu net imposable';

  @override
  String get simulations_taxation_field_parts => 'Nombre de parts';

  @override
  String get simulations_taxation_ir_summary_prefix =>
      'Cette année, vous avez un net imposable de ';

  @override
  String get simulations_taxation_ir_summary_middle =>
      ', induisant un impôt sur le revenu total de ';

  @override
  String get simulations_taxation_ir_stat_quotient => 'Quotient familial';

  @override
  String get simulations_taxation_ir_stat_marginal_rate =>
      'Taux marginal d\'imposition';

  @override
  String get simulations_taxation_ir_stat_total_monthly =>
      'Impôt sur le revenu (total & mensualisé)';

  @override
  String simulations_taxation_bracket_tooltip_title(String label) {
    return 'Tranche $label';
  }

  @override
  String get simulations_taxation_bracket_tooltip_max => 'Montant max';

  @override
  String get simulations_taxation_date_day_placeholder => 'JJ';

  @override
  String get simulations_taxation_date_month_placeholder => 'MM';

  @override
  String get simulations_taxation_date_year_placeholder => 'AAAA';

  @override
  String get investments_section_title => 'Investissements';

  @override
  String get investments_identifier_copied_toast_title => 'Identifiant copié';

  @override
  String get investments_ticker_copied_toast_title => 'Ticker copié';

  @override
  String get investments_quantity_units_suffix => 'unités';

  @override
  String get investments_add_investment_button => 'Ajouter un investissement';

  @override
  String get investments_establishment_select_placeholder =>
      'Établissement (banque)';

  @override
  String get investments_clear_opening_date_button => 'Effacer la date';

  @override
  String strategy_documents_button_label(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Documents ($count)',
      zero: 'Documents',
    );
    return '$_temp0';
  }

  @override
  String get strategy_editor_placeholder => 'Écris ta stratégie...';

  @override
  String get strategy_load_error =>
      'Impossible de charger les notes. Vérifiez que le dossier Coffre-fort est accessible.';

  @override
  String get strategy_select_or_create => 'Sélectionne ou crée une note';

  @override
  String get strategy_new_folder_title => 'Nouveau dossier';

  @override
  String get strategy_rename_folder_title => 'Renommer le dossier';

  @override
  String get strategy_folder_name_placeholder => 'Nom du dossier';

  @override
  String get strategy_folder_color_title => 'Couleur du dossier';

  @override
  String strategy_delete_folder_confirm_title(String name) {
    return 'Supprimer \"$name\" ?';
  }

  @override
  String get strategy_delete_folder_confirm_message =>
      'Les notes qu\'il contient ne seront pas supprimées, seulement rangées de nouveau hors dossier.';

  @override
  String get strategy_move_to_folder_title => 'Déplacer vers un dossier';

  @override
  String get strategy_no_folder_label => 'Sans dossier';

  @override
  String get strategy_duplicate_note_menu_item => 'Dupliquer';

  @override
  String get strategy_notes_panel_title => 'Notes';

  @override
  String get strategy_search_placeholder => 'Rechercher une note...';

  @override
  String get strategy_no_notes => 'Aucune note';

  @override
  String get strategy_change_color_menu_item => 'Changer la couleur';

  @override
  String get investments_price_fresh_badge => 'à jour';

  @override
  String get investments_price_manual_badge => 'manuel';

  @override
  String investments_manual_price_estimated_on(String date) {
    return 'Estimé le $date';
  }

  @override
  String get investments_excluded_from_patrimoine_badge =>
      'Hors patrimoine global';

  @override
  String investments_documents_attached_tooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents rattachés',
      one: '1 document rattaché',
    );
    return '$_temp0 — consulter';
  }

  @override
  String get investments_transaction_type_arbitrage_label => 'Arbitrage';

  @override
  String investments_arbitrage_sold_bought_summary(
    String sellQuantity,
    String sellPrice,
    String buyQuantity,
    String buyPrice,
  ) {
    return 'Vendu $sellQuantity × $sellPrice → Acheté $buyQuantity × $buyPrice';
  }

  @override
  String get investments_manual_price_dialog_title => 'Cours actuel estimé';

  @override
  String investments_manual_price_hint_multi_unit(String quantity) {
    return 'Prix estimé par unité — à mettre à jour toi-même quand tu le juges utile, aucune source de cours automatique n\'existe pour ce placement. La valeur affichée sera ce cours × $quantity unités détenues.';
  }

  @override
  String get investments_manual_price_hint_single_unit =>
      'À mettre à jour toi-même quand tu le juges utile — aucune source de cours automatique n\'existe pour ce placement.';

  @override
  String get investments_field_price_eur => 'Cours (€)';

  @override
  String get investments_pe_valuation_dialog_title => 'Valorisation actuelle';

  @override
  String get investments_pe_valuation_hint =>
      'Dernier NAV/valorisation communiqué par le gérant du fonds — à mettre à jour toi-même quand tu le reçois, aucune source de cours automatique n\'existe pour ce placement.';

  @override
  String get investments_field_valuation_eur => 'Valorisation (€)';

  @override
  String investments_delete_position_confirm_title(String label) {
    return 'Supprimer \"$label\" ?';
  }

  @override
  String get investments_delete_position_confirm_message =>
      'Cette position sera définitivement supprimée.';

  @override
  String get investments_reestimate_pe_valuation_menu_item =>
      'Réestimer la valorisation';

  @override
  String get investments_reestimate_price_menu_item => 'Réestimer le cours';

  @override
  String get investments_transfer_to_other_account_menu_item =>
      'Transférer vers un autre compte';

  @override
  String get investments_arbitrage_to_other_security_menu_item =>
      'Arbitrer vers un autre titre';

  @override
  String get investments_merge_with_other_position_menu_item =>
      'Fusionner avec une autre position';

  @override
  String get investments_delete_position_requires_no_transactions_hint =>
      'Supprime d\'abord ses transactions';

  @override
  String get investments_delete_position_menu_item => 'Supprimer la position';

  @override
  String get investments_isin_copied_toast => 'ISIN copié';

  @override
  String get investments_identifier_copied_toast => 'Identifiant copié';

  @override
  String get investments_ticker_copied_toast => 'Ticker copié';

  @override
  String get investments_stat_net_invested_capital => 'Capital net investi';

  @override
  String get investments_stat_quantity_held => 'Quantité détenue';

  @override
  String get investments_stat_vested => 'Acquis';

  @override
  String get investments_stat_last_price => 'Dernier cours';

  @override
  String get investments_stat_estimated_price => 'Cours estimé';

  @override
  String get investments_stat_valuation => 'Valorisation';

  @override
  String investments_performance_annualized(String percent) {
    return '$percent / an';
  }

  @override
  String investments_performance_since_start(String percent) {
    return '$percent depuis le début';
  }

  @override
  String get investments_insufficient_price_history =>
      'Pas assez d\'historique de cours pour ce calcul.';

  @override
  String get investments_insufficient_transaction_history =>
      'Pas assez d\'historique de transactions pour ce calcul.';

  @override
  String investments_pe_valuation_estimated_on(String date) {
    return 'Valorisation estimée le $date (menu « ⋮ » pour la mettre à jour).';
  }

  @override
  String get investments_pe_no_valuation_hint =>
      'Aucune valorisation renseignée : le montant ci-dessus correspond au capital net investi — menu « ⋮ » pour renseigner le dernier NAV communiqué par le gérant.';

  @override
  String investments_manual_price_estimated_on_menu_hint(String date) {
    return 'Cours estimé le $date (menu « ⋮ » pour le mettre à jour).';
  }

  @override
  String get investments_no_manual_price_hint =>
      'Aucun cours renseigné : la valorisation ci-dessus correspond au montant net investi — menu « ⋮ » pour en ajouter un.';

  @override
  String investments_price_not_found_yahoo(String isin) {
    return 'Cours introuvable sur Yahoo Finance pour « $isin ».';
  }

  @override
  String get investments_price_not_available_yet =>
      'Cours en temps réel pas encore disponible : la valorisation ci-dessus correspond au montant net investi.';

  @override
  String get investments_no_positions_yet => 'Aucune position pour l\'instant.';

  @override
  String get investments_no_open_positions_yet =>
      'Aucune position ouverte pour l\'instant.';

  @override
  String get investments_old_positions_label => 'Anciennes positions';

  @override
  String investments_delete_leveraged_position_confirm_title(String market) {
    return 'Supprimer \"$market\" ?';
  }

  @override
  String get investments_delete_leveraged_position_confirm_message =>
      'Cette position sera définitivement supprimée. Cette action est irréversible.';

  @override
  String get investments_leveraged_section_title =>
      'Positions à effet de levier';

  @override
  String get investments_add_position_link => 'Ajouter une position';

  @override
  String get investments_no_leveraged_positions_yet =>
      'Aucune position à effet de levier pour l\'instant.';

  @override
  String get investments_closed_positions_label => 'Positions fermées';

  @override
  String get investments_column_entry_label => 'Entrée';

  @override
  String get investments_column_price_label => 'Cours';

  @override
  String get investments_column_amount_label => 'Montant';

  @override
  String get investments_pnl_roe_column_label => 'PnL (ROE)';

  @override
  String get investments_refresh_menu_item => 'Actualiser';

  @override
  String get investments_close_position_menu_item => 'Clôturer';

  @override
  String get investments_position_closed_badge => 'Fermée';

  @override
  String investments_liquidation_price_label(String price) {
    return 'Liquidation : $price';
  }

  @override
  String investments_delete_investment_confirm_title(String label) {
    return 'Supprimer \"$label\" ?';
  }

  @override
  String get investments_delete_investment_confirm_message =>
      'Cet investissement sera définitivement supprimé.';

  @override
  String get investments_transfer_to_account_menu_item =>
      'Transférer vers un autre compte';

  @override
  String get investments_arbitrage_to_security_menu_item =>
      'Arbitrer vers un autre titre';

  @override
  String get investments_merge_with_position_menu_item =>
      'Fusionner avec une autre position';

  @override
  String get investments_delete_investment_requires_empty_tooltip =>
      'Supprime d\'abord ses transactions';

  @override
  String get investments_delete_investment_menu_item =>
      'Supprimer l\'investissement';

  @override
  String get investments_receipt_save_dialog_title =>
      'Enregistrer la quittance';

  @override
  String investments_receipt_document_name(String month) {
    return 'Quittance $month';
  }

  @override
  String get investments_receipt_saved_toast_title => 'Quittance enregistrée';

  @override
  String get investments_receipt_save_failed_toast_title =>
      'Échec de l\'enregistrement';

  @override
  String investments_receipt_save_failed_subtitle(String error) {
    return 'La quittance n\'a pas pu être générée ou enregistrée : $error';
  }

  @override
  String get investments_isin_copied_toast_title => 'ISIN copié';

  @override
  String get investments_quantity_held_label => 'Quantité détenue';

  @override
  String get investments_last_price_label => 'Dernier cours';

  @override
  String investments_performance_annualized_label(String rate) {
    return '$rate / an';
  }

  @override
  String investments_performance_since_start_label(String rate) {
    return '$rate depuis le début';
  }

  @override
  String get investments_not_enough_price_history =>
      'Pas assez d\'historique de cours pour ce calcul.';

  @override
  String get investments_twr_explanation =>
      'TWR (Time-Weighted Return) : performance de l\'actif, indépendamment du moment de vos apports.';

  @override
  String get investments_mwr_explanation =>
      'MWR (Money-Weighted Return) : rendement réellement perçu, compte tenu du montant et de la date de chaque apport.';

  @override
  String investments_price_not_found_hint(String isin) {
    return 'Cours introuvable sur Yahoo Finance pour « $isin » : identifiant inconnu ou actif non coté. Vérifiez l\'identifiant — la valorisation ci-dessus correspond au montant net investi (prix d\'achat), pas au cours actuel du marché.';
  }

  @override
  String get investments_price_not_yet_available_hint =>
      'Cours en temps réel pas encore disponible : la valorisation ci-dessus correspond au montant net investi (prix d\'achat), pas au cours actuel du marché.';

  @override
  String get investments_tab_profitability => 'Rentabilité';

  @override
  String get investments_ibkr_import_dialog_title => 'Importer le relevé IBKR';

  @override
  String investments_ibkr_period_label(String start, String end) {
    return 'Période : $start → $end';
  }

  @override
  String get investments_ibkr_row_security_trades =>
      'Achats / ventes de titres';

  @override
  String get investments_ibkr_row_currency_conversions =>
      'Conversions de devise';

  @override
  String get investments_ibkr_row_dividends => 'Dividendes';

  @override
  String get investments_ibkr_row_withholding_tax => 'Retenues à la source';

  @override
  String get investments_ibkr_row_fees => 'Frais';

  @override
  String get investments_ibkr_row_deposits => 'Dépôts';

  @override
  String get investments_ibkr_row_withdrawals => 'Retraits';

  @override
  String get investments_ibkr_row_other_flows => 'Autres mouvements';

  @override
  String get investments_ibkr_empty_state =>
      'Aucune nouvelle transaction à importer — ce fichier a déjà été importé, ou ne contient aucune ligne reconnue.';

  @override
  String investments_ibkr_duplicates_skipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes déjà importées — ignorées.',
      one: '1 ligne déjà importée — ignorée.',
    );
    return '$_temp0';
  }

  @override
  String get investments_ibkr_warnings_title => 'Avertissements';

  @override
  String get investments_ibkr_import_button => 'Importer';

  @override
  String investments_transfer_title(String label) {
    return 'Transférer \"$label\"';
  }

  @override
  String investments_arbitrage_title(String label) {
    return 'Arbitrer \"$label\"';
  }

  @override
  String get investments_transfer_description =>
      'Le PRU est conservé : la vente ici et l\'achat sur le compte de destination utilisent tous deux le PRU actuel — aucune plus-value n\'est réalisée par le transfert lui-même.';

  @override
  String get investments_arbitrage_description =>
      'La vente se fait au cours du marché (réalise la plus/moins-value latente) ; le produit finance exactement l\'achat du nouveau titre.';

  @override
  String get investments_field_pru_kept => 'PRU conservé';

  @override
  String get investments_no_other_account_for_transfer =>
      'Aucun autre compte disponible pour un transfert.';

  @override
  String get investments_field_dest_account => 'Vers le compte';

  @override
  String get investments_field_dest_buy_price =>
      'Prix d\'achat de la destination';

  @override
  String get investments_amount_obtained_placeholder => 'Montant obtenu : —';

  @override
  String investments_amount_obtained_value(String amount) {
    return 'Montant obtenu : $amount';
  }

  @override
  String investments_amount_obtained_with_bought_quantity(
    String amount,
    String quantity,
  ) {
    return 'Montant obtenu : $amount → quantité achetée : $quantity';
  }

  @override
  String get investments_transfer_button => 'Transférer';

  @override
  String get investments_arbitrage_button => 'Arbitrer';

  @override
  String get investments_transfer_impossible_title => 'Transfert impossible';

  @override
  String get investments_arbitrage_impossible_title => 'Arbitrage impossible';

  @override
  String get investments_error_dest_account_required =>
      'Choisis un compte de destination.';

  @override
  String get investments_error_new_position_fields_required =>
      'Renseigne le libellé (et l\'identifiant si nécessaire) de la nouvelle position.';

  @override
  String get investments_error_pru_must_be_positive =>
      'Le PRU doit être un nombre supérieur à 0.';

  @override
  String get dashboard_donut_total => 'Total';

  @override
  String get analyses_title => 'Analyses';

  @override
  String get analyses_tab_performance => 'Performance';

  @override
  String get analyses_tab_risk => 'Risque';

  @override
  String get analyses_tab_composition => 'Composition';

  @override
  String get analyses_tab_financial_structure => 'Structure financière';

  @override
  String get analyses_load_error =>
      'Impossible de charger les analyses. Vérifiez que le dossier Coffre-fort est accessible.';

  @override
  String get analyses_not_calculable => 'Non calculable';

  @override
  String get analyses_unclassified => 'Non classé';

  @override
  String get analyses_fund_style_title => 'Style de gestion';

  @override
  String get analyses_scope_caption => 'Actions & Fonds · aujourd\'hui';

  @override
  String get analyses_fund_style_tooltip =>
      'Répartition de la valeur des investissements Actions & Fonds par style de gestion (gestion active, indicielle...), en % de la valeur totale de cette classe.';

  @override
  String get analyses_no_classified_investments =>
      'Aucun investissement Actions & Fonds classé pour l\'instant.';

  @override
  String get analyses_sector_drop_hint =>
      'Survole ou clique un secteur pour voir les investissements qui le composent.';

  @override
  String get analyses_sector_diversification_title =>
      'Diversification sectorielle';

  @override
  String get analyses_sector_diversification_tooltip =>
      'Répartition de la valeur des investissements Actions & Fonds par secteur d\'activité, en % de la valeur totale de cette classe. Le secteur se règle manuellement sur chaque investissement. Survole ou clique un secteur pour voir les investissements qui le composent.';

  @override
  String get analyses_country_drop_hint =>
      'Survole ou clique un pays pour voir les investissements qui le composent.';

  @override
  String get analyses_geo_diversification_title =>
      'Diversification géographique';

  @override
  String get analyses_geo_diversification_tooltip =>
      'Répartition de la valeur des investissements Actions & Fonds par pays, en % de la valeur totale de cette classe. Le pays se règle manuellement sur chaque investissement. Survole ou clique un pays pour voir les investissements qui le composent.';

  @override
  String get analyses_no_investments => 'Aucun investissement.';

  @override
  String get analyses_risk_return_title => 'Risque et rendement';

  @override
  String get analyses_risk_return_subtitle =>
      'Bêta face au benchmark configuré dans la carte Alpha vs benchmark, si renseigné. Survolez un en-tête de colonne pour le détail de chaque métrique.';

  @override
  String get analyses_risk_metric_volatility => 'Volatilité';

  @override
  String get analyses_risk_metric_volatility_desc =>
      'Écart-type annualisé des rendements journaliers : plus il est élevé, plus la valeur a fluctué au jour le jour sur la période, dans un sens comme dans l\'autre.';

  @override
  String get analyses_risk_metric_max_drawdown => 'Max drawdown';

  @override
  String get analyses_risk_metric_max_drawdown_desc =>
      'Plus forte baisse subie entre un sommet et le creux suivant sur la période — le pire passage traversé, pas la performance finale (qui peut être positive malgré un max drawdown élevé).';

  @override
  String get analyses_risk_metric_sharpe => 'Sharpe';

  @override
  String get analyses_risk_metric_sharpe_desc =>
      'Rendement obtenu par unité de risque total pris (la volatilité) — plus il est élevé, meilleur est le rendement pour le risque supporté. Pénalise autant les fluctuations à la hausse qu\'à la baisse.';

  @override
  String get analyses_risk_metric_sortino => 'Sortino';

  @override
  String get analyses_risk_metric_sortino_desc =>
      'Comme le ratio de Sharpe, mais ne pénalise que les fluctuations à la baisse (une hausse forte n\'est pas traitée comme un risque) — plus représentatif du risque réellement subi par un investisseur.';

  @override
  String get analyses_risk_metric_beta => 'Bêta';

  @override
  String get analyses_risk_metric_beta_desc =>
      'Sensibilité aux mouvements du benchmark configuré dans la carte Alpha vs benchmark : 1 = évolue comme lui, > 1 = amplifie ses mouvements, < 1 = les atténue, négatif = évolue à l\'inverse.';

  @override
  String get analyses_risk_metric_omega => 'Omega';

  @override
  String get analyses_risk_metric_omega_desc =>
      'Rapport entre les gains cumulés et les pertes cumulées sur la période (au-delà d\'un rendement nul) — au-dessus de 1, les gains l\'emportent sur les pertes.';

  @override
  String get analyses_risk_metric_skew => 'Skew';

  @override
  String get analyses_risk_metric_skew_desc =>
      'Asymétrie de la distribution des rendements journaliers : positif = surtout de petites pertes compensées par quelques gros gains ; négatif = surtout des gains modestes exposés à quelques grosses pertes rares.';

  @override
  String get analyses_whole_portfolio => 'Patrimoine entier';

  @override
  String analyses_correlation_title_category(String category) {
    return 'Corrélation — $category';
  }

  @override
  String get analyses_avg_correlation_within_category =>
      'Corrélation moyenne entre les actifs de cette catégorie';

  @override
  String get analyses_correlation_not_enough_investments =>
      'Pas assez d\'investissements avec un historique de cours suffisant dans cette catégorie sur cette période pour calculer une corrélation.';

  @override
  String get analyses_correlation_between_categories_title =>
      'Corrélation entre catégories';

  @override
  String get analyses_avg_correlation_between_categories =>
      'Corrélation moyenne entre catégories';

  @override
  String get analyses_correlation_not_enough_categories =>
      'Pas assez de catégories avec un historique de cours suffisant sur cette période pour calculer une corrélation.';

  @override
  String get analyses_correlation_tooltip =>
      'Indique si les lignes affichées évoluent ensemble : proche de 0 (ou négatif) = bien diversifié, proche de 1 = elles bougent presque toutes ensemble.';

  @override
  String analyses_performance_per_year(String percent) {
    return '$percent / an';
  }

  @override
  String analyses_performance_since_start(String percent) {
    return '$percent depuis le début';
  }

  @override
  String get analyses_tri_title => 'TRI (rendement money-weighted)';

  @override
  String get analyses_tri_tooltip =>
      'Rendement calculé en tenant compte du montant et de la date de chaque versement (méthode MWR) : il reflète le rendement réellement perçu.';

  @override
  String get analyses_unrealized_gain_title => 'Plus-value latente';

  @override
  String get analyses_today => 'Aujourd\'hui';

  @override
  String get analyses_unrealized_gain_tooltip =>
      'Ce que la vente immédiate de tout le patrimoine rapporterait au-delà du coût d\'acquisition — indépendant de la période sélectionnée.';

  @override
  String get analyses_alpha_title => 'Alpha vs benchmark';

  @override
  String get analyses_alpha_tooltip =>
      'Le portefeuille réel est comparé à ce que les mêmes versements (mêmes dates, mêmes montants) auraient donné investis dans le benchmark à la place, plutôt qu\'un indice supposé investi à 100 % dès le début de la période — un apport récent n\'est jamais jugé comme s\'il avait fructifié depuis toujours. Alpha = rendement réel du portefeuille − rendement que ces mêmes flux auraient fait dans le benchmark (deux MWR).';

  @override
  String get analyses_alpha_ticker_placeholder =>
      'Ticker Yahoo Finance (ex: URTH pour un indice monde)';

  @override
  String get analyses_alpha_common_indices => 'Indices courants';

  @override
  String get analyses_alpha_no_ticker =>
      'Renseignez un indice de référence pour calculer l\'alpha.';

  @override
  String get analyses_alpha_no_history =>
      'Historique du benchmark introuvable ou pas encore synchronisé — réessayez plus tard.';

  @override
  String get analyses_portfolio_label => 'Portefeuille';

  @override
  String get analyses_alpha_label => 'Alpha';

  @override
  String get analyses_debt_leverage_title => 'Endettement et levier';

  @override
  String get analyses_total_assets_label => 'Actifs totaux';

  @override
  String get analyses_total_liabilities_label => 'Passifs totaux';

  @override
  String get analyses_debt_ratio_assets_label => 'Taux d\'endettement (actifs)';

  @override
  String get analyses_debt_ratio_assets_tooltip =>
      'Dette totale rapportée aux actifs totaux — plus il est élevé, plus le patrimoine est financé par l\'emprunt.';

  @override
  String get analyses_debt_ratio_income_label =>
      'Taux d\'endettement (revenus)';

  @override
  String get analyses_debt_ratio_income_missing =>
      'Renseignez vos revenus du mois dans Budget > Suivi';

  @override
  String get analyses_debt_ratio_income_tooltip =>
      'Mensualités de crédit rapportées aux revenus mensuels renseignés dans Budget > Suivi.';

  @override
  String get analyses_leverage_label => 'Levier';

  @override
  String get analyses_leverage_tooltip =>
      'Actifs totaux rapportés au patrimoine net — au-dessus de 1, une partie des actifs est financée par la dette.';
}
