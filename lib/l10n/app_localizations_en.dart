// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get academy_button_completed => 'Completed';

  @override
  String get academy_button_mark_completed => 'Mark as completed';

  @override
  String get academy_disclaimer =>
      'Educational and informational content only, not investment advice: we are not wealth management advisors (CGP). Everyone makes their own financial decisions — the goal is simply to give as many people as possible the keys to decide with full knowledge.';

  @override
  String get academy_takeaway_title => 'Key takeaway';

  @override
  String get academy_vocabulary_title => 'Vocabulary';

  @override
  String get analyses_benchmark_chart_not_enough_data =>
      'Not enough data for this period';

  @override
  String get analyses_stocks_funds_label => 'Stocks & Funds';

  @override
  String get appName => 'Opime';

  @override
  String budget_default_snapshot_name(Object date) {
    return 'Budget of $date';
  }

  @override
  String get common_active => 'Active';

  @override
  String get common_add => 'Add';

  @override
  String get common_back => 'Back';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_category => 'Category';

  @override
  String get common_close => 'Close';

  @override
  String get common_confirm => 'Confirm';

  @override
  String get common_create => 'Create';

  @override
  String get common_date => 'Date';

  @override
  String get common_delete => 'Delete';

  @override
  String get common_description => 'Description';

  @override
  String get common_edit => 'Edit';

  @override
  String get common_error => 'Error';

  @override
  String get common_loading => 'Loading...';

  @override
  String get common_name => 'Name';

  @override
  String get common_next => 'Next';

  @override
  String get common_no => 'No';

  @override
  String get common_none => 'None';

  @override
  String get common_ok => 'OK';

  @override
  String get common_open => 'Open';

  @override
  String get common_page_not_found => 'Page not found';

  @override
  String get common_principal => 'Primary';

  @override
  String get common_remove => 'Remove';

  @override
  String get common_rename => 'Rename';

  @override
  String get common_reset => 'Reset';

  @override
  String get common_save => 'Save';

  @override
  String get common_search => 'Search';

  @override
  String get common_see => 'View';

  @override
  String get common_switch => 'Switch';

  @override
  String get common_title => 'Title';

  @override
  String get common_total => 'TOTAL';

  @override
  String get common_yes => 'Yes';

  @override
  String get dashboard_allocation_title => 'Allocation';

  @override
  String get dashboard_assets_label => 'Assets';

  @override
  String get dashboard_assets_title => 'Assets';

  @override
  String get dashboard_liabilities_label => 'Liabilities';

  @override
  String get dashboard_not_enough_data_period =>
      'Not enough data for this period';

  @override
  String get dashboard_onboarding_cta_hint => 'Click here to get started';

  @override
  String get dashboard_onboarding_empty_description =>
      'Add your accounts, investments and loans to see your net worth, allocation and how they evolve. Use the \"Complete my portfolio\" button at the top of the screen.';

  @override
  String get dashboard_onboarding_empty_title => 'Your dashboard is empty';

  @override
  String get investments_add_transaction_submit => 'Add transaction';

  @override
  String get investments_add_transaction_title => 'Add a transaction';

  @override
  String get investments_amount_placeholder => 'Amount: —';

  @override
  String investments_amount_value(String amount) {
    return 'Amount: $amount';
  }

  @override
  String investments_amount_with_bought_quantity(
    String amount,
    String quantity,
  ) {
    return 'Amount: $amount → quantity bought: $quantity';
  }

  @override
  String investments_delay_days(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String investments_delay_months(int months) {
    return '$months months';
  }

  @override
  String investments_delay_years(int years) {
    return '$years years';
  }

  @override
  String get investments_delete_linked_transaction_message =>
      'This transaction is part of a transfer/arbitrage: its counterpart will also be deleted. This action is irreversible and will change the quantity held and the average cost of both positions.';

  @override
  String investments_delete_transaction_message(String label) {
    return 'This action is irreversible and will change the quantity held and the average cost of \"$label\".';
  }

  @override
  String get investments_delete_transaction_title => 'Delete this transaction?';

  @override
  String get investments_edit_arbitrage_title => 'Edit arbitrage';

  @override
  String get investments_edit_impossible_title => 'Unable to edit';

  @override
  String investments_edit_transaction_title(String label) {
    return 'Edit transaction — $label';
  }

  @override
  String get investments_error_buy_price_must_be_positive =>
      'Buy price must be a number greater than 0.';

  @override
  String get investments_error_date_required => 'Date is required.';

  @override
  String investments_error_quantity_exceeds_sellable(
    String quantity,
    String maxSellable,
  ) {
    return 'The quantity ($quantity) exceeds the quantity that would be held ($maxSellable).';
  }

  @override
  String get investments_error_quantity_must_be_positive =>
      'Quantity must be a number greater than 0.';

  @override
  String get investments_error_sell_price_must_be_positive =>
      'Sell price must be a number greater than 0.';

  @override
  String get investments_estimate_button => 'Estimate';

  @override
  String investments_field_amount_currency(String currency) {
    return 'Amount ($currency)';
  }

  @override
  String get investments_field_amount_eur => 'Amount (€)';

  @override
  String get investments_field_amount_paid_eur => 'Amount paid (€)';

  @override
  String get investments_field_buy_price => 'Buy price';

  @override
  String get investments_field_currency_pair_rate => 'Currency pair rate';

  @override
  String get investments_field_position => 'Position';

  @override
  String get investments_field_quantity => 'Quantity';

  @override
  String get investments_field_sell_price => 'Sell price';

  @override
  String get investments_field_shares_options_count =>
      'Number of shares/options';

  @override
  String get investments_field_total_amount_eur => 'Total amount (€)';

  @override
  String get investments_field_unit_price => 'Unit price';

  @override
  String investments_fiscal_advantage_active_since(String date) {
    return 'Tax advantage active since $date';
  }

  @override
  String investments_fiscal_advantage_upcoming(String date, String delay) {
    return 'Tax advantage on $date (in $delay)';
  }

  @override
  String investments_fx_converted_amount(String amount) {
    return 'Amount ≈ $amount';
  }

  @override
  String get investments_fx_rate_automatic_button => 'Automatic';

  @override
  String investments_fx_rate_display(String currency, String rate) {
    return '1 $currency ≈ $rate €';
  }

  @override
  String get investments_fx_rate_manual_button => 'Manual rate';

  @override
  String investments_fx_rate_manual_hint(String currency) {
    return 'Exchange rate (1 $currency in €)';
  }

  @override
  String get investments_fx_rate_searching => 'Looking up the exchange rate…';

  @override
  String get investments_identifier_choose_placeholder => 'Choose...';

  @override
  String get investments_identifier_generic_hint =>
      'Identifier (ISIN, or free-form: address, reference...)';

  @override
  String get investments_identifier_isin_optional_hint =>
      'ISIN (optional: leave blank if the fund doesn\'t have one)';

  @override
  String get investments_identifier_optional_hint =>
      'Identifier (optional: leave blank if the fund doesn\'t have one)';

  @override
  String get investments_identifier_reference_hint =>
      'Reference (optional: serial number, reference...)';

  @override
  String investments_mwr_annualized(String percent) {
    return '$percent per year (MWR, money-weighted return)';
  }

  @override
  String investments_mwr_since_start(String percent) {
    return '$percent since inception (MWR, less than a year of history)';
  }

  @override
  String get investments_net_invested_amount_pending_price =>
      'Net amount invested (price not yet available for all investments)';

  @override
  String get investments_new_position_option => '+ New position';

  @override
  String get investments_no_data_yet => 'No data yet.';

  @override
  String get investments_no_transactions_yet => 'No transactions yet.';

  @override
  String investments_opened_on(String date) {
    return 'Opened on $date';
  }

  @override
  String get investments_price_sync_offline_message =>
      'Unable to update prices and performance: check your internet connection.';

  @override
  String get investments_property_type_apartment => 'Apartment';

  @override
  String get investments_property_type_house => 'House';

  @override
  String get investments_reestimate_dialog_title =>
      'Re-estimate the value (€/m²)';

  @override
  String get investments_reestimate_missing_fields_error =>
      'Enter an address and a surface area.';

  @override
  String get investments_reestimate_no_comparable_sale_error =>
      'No comparable sale found for this address.';

  @override
  String investments_save_error(String error) {
    return 'Error while saving: $error';
  }

  @override
  String get investments_surface_m2_label => 'Surface area (m²)';

  @override
  String get investments_valuation_last_known_price =>
      'Valuation at last known price';

  @override
  String get liabilities_delete_confirm_message =>
      'This liability will be permanently deleted.';

  @override
  String liabilities_delete_confirm_title(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get liabilities_paid_off => 'Paid off';

  @override
  String liabilities_remaining_balance_subtitle(String amount) {
    return 'Remaining balance, out of $amount borrowed';
  }

  @override
  String get nav_academy => 'Academy';

  @override
  String get nav_analyses => 'Analyses';

  @override
  String get nav_assets => 'Assets';

  @override
  String get nav_assistant => 'Assistant';

  @override
  String get nav_budget => 'Budget';

  @override
  String get nav_budget_allocation => 'Allocation';

  @override
  String get nav_budget_tracking => 'Tracking';

  @override
  String get nav_dashboard => 'Dashboard';

  @override
  String get nav_entities => 'Entities';

  @override
  String get nav_home => 'Home';

  @override
  String get nav_liabilities => 'Liabilities';

  @override
  String get nav_patrimoine => 'Net worth';

  @override
  String get nav_professional => 'Professional';

  @override
  String get nav_projects => 'Projects';

  @override
  String get nav_settings => 'Settings';

  @override
  String get nav_simulation => 'Simulation';

  @override
  String get nav_simulation_real_estate => 'Real estate';

  @override
  String get nav_simulation_taxation => 'Taxation';

  @override
  String get nav_simulation_transmission => 'Transmission';

  @override
  String get nav_simulation_wealth => 'Net worth';

  @override
  String get nav_strategy => 'Strategy';

  @override
  String get nav_tools => 'Tools';

  @override
  String get settings_account_name_hint => 'Name (e.g. Camille)';

  @override
  String get settings_add_account => 'Add an account';

  @override
  String get settings_add_vault => 'Add a vault';

  @override
  String settings_api_key(String provider) {
    return '$provider API key';
  }

  @override
  String get settings_api_key_placeholder => 'Paste your API key here';

  @override
  String get settings_appearance => 'Appearance';

  @override
  String get settings_assistant => 'AI Assistant';

  @override
  String get settings_checking_releases => 'Checking GitHub releases...';

  @override
  String settings_cloud_description(String provider) {
    return 'Dialogue with $provider using your own API key: net worth analyses, educational explanations, questions about your simulations and strategy.';
  }

  @override
  String get settings_cloud_include_patrimoine =>
      ' and the summary of your net worth';

  @override
  String settings_cloud_warning(String provider, String includePatrimoine) {
    return 'With $provider, your messages$includePatrimoine are sent to this provider\'s servers, off your machine.';
  }

  @override
  String get settings_comptes => 'Accounts';

  @override
  String get settings_comptes_description =>
      'Keep the net worth, budget and strategy notes of each person in the active vault separate.';

  @override
  String get settings_create_account => 'Create account';

  @override
  String get settings_dark => 'Dark';

  @override
  String get settings_download_install => 'Download & install';

  @override
  String get settings_encryption => 'Vault encryption';

  @override
  String get settings_encryption_disable => 'Disable encryption';

  @override
  String get settings_encryption_disabled =>
      'Encrypt the private data of this vault with a password you define. Public caches (market prices, real estate data, rents...) always stay in clear.';

  @override
  String get settings_encryption_enable => 'Enable encryption';

  @override
  String get settings_encryption_enabled =>
      'The private data of this vault (accounts, budget, liabilities, projects, strategy notes, simulations) is encrypted. The password is asked again at each app launch.';

  @override
  String get settings_encryption_regenerate_key =>
      'Generate a new recovery key';

  @override
  String get settings_include_patrimoine_context =>
      'Include a summary of my net worth in the model context';

  @override
  String get settings_language => 'Language';

  @override
  String get settings_language_description =>
      'Choose the display language of the application. \"System\" uses your device language.';

  @override
  String get settings_language_english => 'English';

  @override
  String get settings_language_french => 'Français';

  @override
  String get settings_language_system => 'System';

  @override
  String get settings_light => 'Light';

  @override
  String settings_new_version(String version) {
    return 'New version detected: $version';
  }

  @override
  String get settings_news => 'News';

  @override
  String get settings_news_description =>
      'Yahoo Finance news for your held stocks/ETFs, and price variation alerts (CoinGecko) for your held cryptocurrencies. No network request is made if disabled.';

  @override
  String get settings_ollama_address => 'Ollama server address';

  @override
  String get settings_ollama_description =>
      'Dialogue with a local Ollama model (gemma, llama...): net worth analyses, educational explanations, questions about your simulations and strategy. Everything stays on your machine — no data is sent online. Ollama must run in the background (« ollama serve ») and the models are installed with « ollama pull <model> ».';

  @override
  String get settings_ollama_reset_default => 'Restore default address';

  @override
  String get settings_profile_name => 'Name';

  @override
  String get settings_profile_name_hint => 'Name (e.g. Camille)';

  @override
  String get settings_profile_relationship => 'Relationship';

  @override
  String get settings_profile_relationship_hint => 'Relationship (e.g. Spouse)';

  @override
  String get settings_provider => 'Provider';

  @override
  String get settings_relation_name => 'Relationship';

  @override
  String get settings_relationship_hint => 'Relationship (e.g. Spouse)';

  @override
  String get settings_remote_version_unknown => 'Remote version unknown.';

  @override
  String get settings_shortcuts => 'Keyboard shortcuts';

  @override
  String get settings_system => 'System';

  @override
  String get settings_tax_parameters => 'Tax parameters';

  @override
  String get settings_tax_parameters_description =>
      'Rates, thresholds and allowances used by the simulators (income tax, IFI, split ownership, donation, inheritance) — update them yourself if the State revises them.';

  @override
  String settings_up_to_date(String version) {
    return 'You are up to date (latest: $version).';
  }

  @override
  String get settings_update_check_failed =>
      'Unable to check for updates right now.';

  @override
  String settings_vault_activate_failed(Object error) {
    return 'Unable to activate this vault: $error';
  }

  @override
  String settings_vault_add_failed(Object error) {
    return 'Unable to add a vault: $error';
  }

  @override
  String settings_vault_forget_failed(Object error) {
    return 'Unable to forget this vault: $error';
  }

  @override
  String get settings_vault_name_hint => 'Vault name';

  @override
  String get settings_vault_pick_dialog_title =>
      'Choose or create an Opime vault';

  @override
  String get settings_vaults => 'Vaults';

  @override
  String get settings_vaults_description =>
      'Add several vaults, give them a name, switch between them and forget them without touching the data on disk.';

  @override
  String settings_version_installed(String version) {
    return 'Installed version: $version';
  }

  @override
  String get settings_version_updates => 'Version & updates';

  @override
  String get settings_view_release => 'View release';

  @override
  String get shell_assistant_response_ready => 'Assistant response ready';

  @override
  String get shell_finish_migration_before_export =>
      'Finish the vault migration before exporting.';

  @override
  String get shell_migration_pending => 'Migration pending';

  @override
  String get shell_no_profile_loaded => 'No profile loaded';

  @override
  String get shell_one_response_ready => 'A response is ready';

  @override
  String get shell_profiles_load_failed =>
      'Unable to load the profiles. The Vault folder may still be syncing.';

  @override
  String get shell_response_interrupted => 'Response interrupted';

  @override
  String get shell_response_interrupted_subtitle =>
      'The profile or vault changed during generation.';

  @override
  String shell_responses_pending(int count) {
    return '$count responses pending';
  }

  @override
  String get shell_retry_after_vault_loaded =>
      'Try again once the vault is loaded.';

  @override
  String get shell_unlock_before_export =>
      'Unlock your vault before exporting.';

  @override
  String get shell_vault_locked => 'Vault locked';

  @override
  String get sidebar_account => 'Account';

  @override
  String get sidebar_accounts => 'Accounts';

  @override
  String get sidebar_collapse => 'Collapse';

  @override
  String get sidebar_expand => 'Expand';

  @override
  String get sidebar_switch_account => 'switch account';

  @override
  String get academy_envelope_ceiling_label => 'Ceiling';

  @override
  String get academy_envelope_good_to_know_title => 'Good to know';

  @override
  String get academy_envelope_ideal_for_label => 'Ideal for';

  @override
  String get academy_envelope_liquidity_label => 'Liquidity';

  @override
  String get academy_envelope_pitfall_label => 'Pitfall — ';

  @override
  String get academy_envelope_taxation_label => 'Taxation';

  @override
  String get academy_level_avance => 'Advanced';

  @override
  String get academy_level_debutant => 'Beginner';

  @override
  String get academy_level_intermediaire => 'Intermediate';

  @override
  String academy_progress_summary(int count, int total) {
    return '$count / $total completed';
  }

  @override
  String get assistant_attach_document_tooltip =>
      'Attach a document (PDF, TXT, MD)';

  @override
  String get assistant_choose_model_first => 'Pick a model first';

  @override
  String assistant_configure_api_key_prompt(String provider) {
    return 'Set up your $provider API key in Settings → AI Assistant.';
  }

  @override
  String get assistant_disabled_description =>
      'Enable the assistant in Settings to analyze your net worth, explain financial concepts and answer your questions — with a local Ollama model (no data leaves your machine) or a cloud provider connected via an API key.';

  @override
  String get assistant_disabled_title => 'AI Assistant disabled';

  @override
  String get assistant_document_read_error_generic_title =>
      'Error reading document';

  @override
  String get assistant_document_read_error_title =>
      'Unable to read this document';

  @override
  String assistant_document_truncated_subtitle(String fileName) {
    return '\"$fileName\" exceeds the supported size: only the beginning was sent to the assistant.';
  }

  @override
  String get assistant_document_truncated_title => 'Document truncated';

  @override
  String get assistant_document_truncated_tooltip =>
      'Document truncated: only the beginning was sent to the assistant.';

  @override
  String get assistant_empty_state_description =>
      'Ask a question about your net worth, simulations or strategy. Answers use your local data if the context option is enabled.';

  @override
  String get assistant_empty_state_title => 'What would you like to know?';

  @override
  String assistant_error_generic(String error) {
    return 'Error: $error';
  }

  @override
  String get assistant_input_placeholder =>
      'Ask a question about your net worth…';

  @override
  String get assistant_model_placeholder => 'Model';

  @override
  String get assistant_model_setup_help =>
      'To enable the assistant: install Ollama from ollama.com and launch it, then run \"ollama pull llama3.2\" in a terminal and click Refresh.';

  @override
  String get assistant_multiple_responses_generating =>
      'Multiple responses generating…';

  @override
  String get assistant_new_conversation => 'New conversation';

  @override
  String assistant_no_model_cloud(String provider) {
    return 'No model available for this $provider key.';
  }

  @override
  String get assistant_no_model_ollama => 'No model is installed on Ollama.';

  @override
  String get assistant_open_settings => 'Open Settings';

  @override
  String get assistant_refresh_model_list => 'Refresh the list';

  @override
  String get assistant_retry => 'Retry';

  @override
  String get assistant_send => 'Send';

  @override
  String get assistant_stop_generation => 'Stop generation';

  @override
  String get assistant_suggestion_analyze_patrimoine => 'Analyze my net worth';

  @override
  String get assistant_suggestion_explain_allocation => 'Explain my allocation';

  @override
  String get assistant_suggestion_simulations_summary =>
      'What do my simulations say?';

  @override
  String get assistant_suggestion_summarize_strategy => 'Summarize my strategy';

  @override
  String get budget_add_category => 'Add a category';

  @override
  String get budget_add_revenue_source => 'Add a revenue source';

  @override
  String get budget_amount_placeholder => 'Amount';

  @override
  String get budget_bucket_dettes => 'Debts';

  @override
  String get budget_bucket_factures => 'Bills';

  @override
  String get budget_bucket_invest_epargne => 'Invest/Savings';

  @override
  String get budget_distribution_title => 'Distribution';

  @override
  String budget_duplicate_name_suffix(String name) {
    return '$name (copy)';
  }

  @override
  String get budget_duplicate_tooltip => 'Duplicate this budget';

  @override
  String get budget_history_empty => 'No budgets saved.';

  @override
  String get budget_history_title => 'Allocated budgets';

  @override
  String get budget_inout_header => 'INCOME / EXPENSES';

  @override
  String get budget_landscape_suggestion =>
      'Use landscape mode for better readability';

  @override
  String get budget_legend_realite => 'Actual';

  @override
  String get budget_load_error =>
      'Unable to load budgets. Make sure the Vault folder is accessible.';

  @override
  String get budget_month_april => 'April';

  @override
  String get budget_month_august => 'August';

  @override
  String get budget_month_december => 'December';

  @override
  String get budget_month_february => 'February';

  @override
  String get budget_month_flow_title => 'Monthly flow';

  @override
  String get budget_month_january => 'January';

  @override
  String get budget_month_july => 'July';

  @override
  String get budget_month_june => 'June';

  @override
  String get budget_month_march => 'March';

  @override
  String get budget_month_may => 'May';

  @override
  String get budget_month_november => 'November';

  @override
  String get budget_month_october => 'October';

  @override
  String get budget_month_september => 'September';

  @override
  String get budget_name_placeholder => 'Budget name';

  @override
  String get budget_new_budget => 'New budget';

  @override
  String get budget_no_data => 'No data';

  @override
  String get budget_no_results => 'No results.';

  @override
  String get budget_redo_shortcut_windows => 'Ctrl+Shift+Z';

  @override
  String budget_redo_tooltip(String shortcut) {
    return 'Redo ($shortcut)';
  }

  @override
  String get budget_remaining_amount_label => 'Remaining amount';

  @override
  String get budget_revenue_name_placeholder => 'Revenue name';

  @override
  String budget_sankey_deficit_label(
    String label,
    String amount,
    String deficit,
  ) {
    return '$label: $amount (deficit of $deficit)';
  }

  @override
  String get budget_sankey_empty_message =>
      'Add revenues, expenses or investments to see the flow.';

  @override
  String get budget_sankey_expense_fallback => 'Expense';

  @override
  String get budget_sankey_investment_fallback => 'Investment';

  @override
  String get budget_sankey_no_data_fallback => 'No data yet for this flow.';

  @override
  String budget_sankey_node_label(String label, String amount) {
    return '$label: $amount';
  }

  @override
  String get budget_sankey_revenue_fallback => 'Revenue';

  @override
  String get budget_sankey_uncategorized => 'Uncategorized';

  @override
  String get budget_save_chart_dialog_title => 'Save chart';

  @override
  String get budget_saved_toast => 'Budget saved';

  @override
  String get budget_search_placeholder => 'Search budgets...';

  @override
  String get budget_section_depenses => 'EXPENSES';

  @override
  String get budget_section_dettes => 'DEBTS';

  @override
  String get budget_section_factures => 'BILLS';

  @override
  String get budget_section_invest_epargne => 'INVEST / SAVINGS';

  @override
  String get budget_section_projets => 'PROJECTS';

  @override
  String get budget_section_revenues => 'REVENUES';

  @override
  String get budget_summary_available => ' available.';

  @override
  String get budget_summary_expenses => ', expenses of ';

  @override
  String get budget_summary_inout_title => 'Income/expense summary';

  @override
  String get budget_summary_intro => 'Your savings rate is ';

  @override
  String get budget_summary_invest => ' and invest ';

  @override
  String get budget_summary_possible_rate => ' (possible savings rate: ';

  @override
  String get budget_summary_remaining => ' every month, you have ';

  @override
  String get budget_summary_row_depenses => '- Expenses';

  @override
  String get budget_summary_row_dettes => '- Debts';

  @override
  String get budget_summary_row_factures => '- Bills';

  @override
  String get budget_summary_row_invest => '- Invest/Savings';

  @override
  String get budget_summary_row_projets => '- Projects';

  @override
  String get budget_summary_row_remaining => 'REMAINING';

  @override
  String get budget_summary_row_revenues => '+ Revenues';

  @override
  String get budget_summary_total_income => '). Your total income is ';

  @override
  String get budget_tab_expenses => 'Expenses';

  @override
  String get budget_tab_investments => 'Investments';

  @override
  String get budget_tab_revenues => 'Revenues';

  @override
  String get budget_templates_nudge_apply => 'Add to month';

  @override
  String budget_templates_nudge_message(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recurring lines available — add them to this month?',
      one: '1 recurring line available — add it to this month?',
    );
    return '$_temp0';
  }

  @override
  String get budget_tracking_sankey_empty_message =>
      'Enter amounts in the Actual columns to see this month\'s flow.';

  @override
  String get budget_tracking_subtitle => 'Tracking board';

  @override
  String budget_undo_tooltip(String shortcut) {
    return 'Undo ($shortcut)';
  }

  @override
  String get common_continue => 'Continue';

  @override
  String get common_retry => 'Retry';

  @override
  String get core_ui_new_vault_kind_prompt => 'This vault is...';

  @override
  String get core_ui_new_vault_title => 'New vault';

  @override
  String get core_ui_pick_date => 'Pick a date';

  @override
  String get core_ui_vault_kind_personal => 'Personal';

  @override
  String get dashboard_chart_all_categories => 'All';

  @override
  String dashboard_chart_categories_count(int count) {
    return '$count classes';
  }

  @override
  String get dashboard_chart_category_empty => '(empty)';

  @override
  String get dashboard_column_change => 'Change';

  @override
  String get dashboard_column_pnl => '+/- value';

  @override
  String get dashboard_column_pru => 'Avg. cost';

  @override
  String get dashboard_column_value => 'Value';

  @override
  String get dashboard_extreme_percent_tooltip =>
      'Huge percentage because the period starts with a very small amount (e.g. first tiny transaction) — most of the increase comes from contributions added since, not actual gains.';

  @override
  String get dashboard_mwr_tooltip =>
      'Return calculated taking into account the amount and date of each contribution (MWR method): it reflects the return actually earned.';

  @override
  String get dashboard_patrimoine_brut_label => 'Gross net worth';

  @override
  String get dashboard_patrimoine_net_label => 'Net worth';

  @override
  String get dashboard_top_assets_title => 'Top performers';

  @override
  String get dashboard_view_by_account => 'By account';

  @override
  String get dashboard_view_by_investment => 'By investment';

  @override
  String get entities_accounts_section_title => 'Accounts';

  @override
  String get entities_add_button => 'Add an entity';

  @override
  String entities_card_diluted_suffix(Object percent) {
    return '$percent % is your final share';
  }

  @override
  String entities_card_net_total(Object amount) {
    return 'of $amount net';
  }

  @override
  String entities_card_ownership_direct(String type, String percent) {
    return '$type · $percent % owned';
  }

  @override
  String entities_card_ownership_via_parent(
    String type,
    String percent,
    String parent,
  ) {
    return '$type · $percent % owned via $parent';
  }

  @override
  String get entities_delete_confirm_message =>
      'This entity will be permanently deleted. Its existing accounts/liabilities are not deleted but will no longer be linked to any entity.';

  @override
  String get entities_detail_load_error =>
      'Unable to load this entity\'s accounts. Check that the Vault folder is accessible.';

  @override
  String entities_dilution_note(Object name) {
    return 'Do not count this entity\'s value in the balance sheet of $name — the ownership link handles this.';
  }

  @override
  String get entities_editor_edit_title => 'Edit entity';

  @override
  String get entities_editor_new_title => 'New entity';

  @override
  String get entities_empty_list_hint =>
      'No entities yet — add a holding, a commercial company, an SCI, or a pro account.';

  @override
  String get entities_included_in_net_worth_hint =>
      'Included in your net worth (Dashboard, Analyses).';

  @override
  String get entities_liabilities_section_title => 'Liabilities';

  @override
  String get entities_load_error =>
      'Unable to load entities. Check that the Vault folder is accessible.';

  @override
  String get entities_name_hint => 'Name (e.g. Dupont Holding)';

  @override
  String get entities_name_required_error => 'Name is required.';

  @override
  String get entities_net_value_label => 'Net value';

  @override
  String get entities_no_accounts_yet =>
      'No accounts yet — use \"Complete my net worth\" while selecting this entity.';

  @override
  String get entities_no_liabilities_yet => 'No liabilities yet.';

  @override
  String get entities_owned_by_label => 'Owned by';

  @override
  String get entities_owned_by_self => 'Me (directly)';

  @override
  String entities_ownership_by_parent(String type, String percent) {
    return '$type · $percent % owned by its parent company';
  }

  @override
  String entities_ownership_by_user(String type, String percent) {
    return '$type · $percent % owned by you';
  }

  @override
  String get entities_parent_company_fallback => 'its parent company';

  @override
  String get entities_percent_direct_hint => '% owned directly by you';

  @override
  String entities_percent_via_parent_hint(Object name) {
    return '% owned by $name';
  }

  @override
  String get entities_total_net_value_label =>
      'Net value held via professional entities';

  @override
  String get entities_type_label => 'Type';

  @override
  String get investments_account_description_hint =>
      'Description (optional, e.g. Holiday savings)';

  @override
  String get investments_account_has_transactions => 'contains transactions';

  @override
  String get investments_account_name_hint_crypto =>
      'Account name (e.g. Coinbase)';

  @override
  String get investments_account_name_hint_generic => 'Account name';

  @override
  String get investments_account_name_hint_precious_metals =>
      'Account name (e.g. Personal safe)';

  @override
  String get investments_account_name_hint_private_equity =>
      'Account name (e.g. Moonfare)';

  @override
  String get investments_account_name_hint_real_estate =>
      'Account name (e.g. Primary residence)';

  @override
  String get investments_account_name_hint_savings =>
      'Account name (e.g. Savings account)';

  @override
  String get investments_account_name_hint_stocks =>
      'Account name (e.g. PEA Boursorama)';

  @override
  String get investments_add_custom_type_label => '+ New type';

  @override
  String get investments_bank_name_hint => 'Bank (e.g. Boursorama)';

  @override
  String get investments_comment_hint => 'Comment (optional)';

  @override
  String get investments_country_breakdown_title => 'Country breakdown';

  @override
  String get investments_country_placeholder => 'Country';

  @override
  String get investments_create_account_label => 'Create account';

  @override
  String get investments_create_investment_label => 'Create investment';

  @override
  String get investments_create_liability_label => 'Create liability';

  @override
  String get investments_cumulative_funding_number_error =>
      'Cumulative funding must be a number.';

  @override
  String get investments_delete_account_confirm_message =>
      'This account and its investments (without transactions) will be permanently deleted.';

  @override
  String investments_delete_account_confirm_title(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String investments_delete_account_dialog_subtitle(String establishment) {
    return 'Accounts at $establishment — only those without transactions can be deleted.';
  }

  @override
  String get investments_delete_account_dialog_title => 'Delete an account';

  @override
  String get investments_entry_price_label => 'Entry price';

  @override
  String get investments_establishment_name_hint =>
      'Establishment name (e.g. Boursorama)';

  @override
  String get investments_exercise_deadline_hint =>
      'Exercise deadline (optional)';

  @override
  String get investments_existing_accounts_label => 'Existing accounts';

  @override
  String get investments_finish_without_transaction_label =>
      'Finish without transaction';

  @override
  String get investments_fund_style_hint => 'Management style (optional)';

  @override
  String get investments_fund_style_placeholder => 'Management style';

  @override
  String get investments_item_name_hint => 'Name (e.g. Rolex Submariner)';

  @override
  String get investments_label_hint_precious_metals =>
      'Label (e.g. Amundi Physical Gold ETC)';

  @override
  String get investments_label_hint_private_equity =>
      'Label (e.g. Ardian Expansion Fund)';

  @override
  String get investments_label_hint_stocks => 'Label (e.g. TotalEnergies)';

  @override
  String get investments_leverage_hint => 'Leverage (e.g. 2)';

  @override
  String get investments_leveraged_edit_title => 'Edit position';

  @override
  String get investments_leveraged_entry_fx_rate_required_error =>
      'The entry price exchange rate is required.';

  @override
  String get investments_leveraged_entry_price_positive_error =>
      'The entry price must be greater than 0.';

  @override
  String investments_leveraged_estimated_liquidation(String amount) {
    return 'Liquidation (estimated): $amount';
  }

  @override
  String get investments_leveraged_leverage_positive_error =>
      'Leverage must be greater than 0.';

  @override
  String investments_leveraged_margin(String amount) {
    return 'Margin: $amount';
  }

  @override
  String get investments_leveraged_market_required_error =>
      'The market (e.g. BTC) is required.';

  @override
  String get investments_leveraged_new_title => 'New leveraged position';

  @override
  String investments_leveraged_notional_amount(String amount) {
    return 'Position amount: $amount';
  }

  @override
  String get investments_leveraged_opening_date_required_error =>
      'The opening date is required.';

  @override
  String get investments_leveraged_position_label => 'Leveraged position';

  @override
  String get investments_leveraged_save_impossible_title =>
      'Unable to save position';

  @override
  String get investments_leveraged_size_positive_error =>
      'Size must be greater than 0.';

  @override
  String get investments_linked_asset_label => 'Linked asset (optional)';

  @override
  String get investments_mark_price_positive_error =>
      'The mark price must be greater than 0.';

  @override
  String get investments_market_hint => 'Market (e.g. BTC)';

  @override
  String get investments_market_placeholder => 'Market';

  @override
  String get investments_merge_choose_destination_message =>
      'Choose the position to merge into.';

  @override
  String investments_merge_dialog_description(String label) {
    return 'To fix the same position entered twice under different names — not for a real financial move (use \"Arbitrate\" for that). All transactions of \"$label\" are moved as-is (same dates, quantities, prices) to the position chosen below, then \"$label\" is deleted. This action is irreversible.';
  }

  @override
  String investments_merge_dialog_title(String label) {
    return 'Merge \"$label\"';
  }

  @override
  String get investments_merge_impossible_title => 'Unable to merge';

  @override
  String get investments_merge_no_other_position_message =>
      'No other position in this account to merge into.';

  @override
  String get investments_merge_submit_button => 'Merge';

  @override
  String get investments_merge_target_label => 'Merge into';

  @override
  String get investments_new_account_section_label => 'New account';

  @override
  String get investments_new_custom_type_hint => 'e.g. Collectible wines';

  @override
  String get investments_new_custom_type_title => 'New type';

  @override
  String investments_next_unlock(String amount, String date) {
    return 'Next unlock: $amount on $date';
  }

  @override
  String get investments_note_hint => 'Note (optional)';

  @override
  String get investments_opening_date_hint => 'Opening date (optional)';

  @override
  String get investments_opening_date_label => 'Opening date';

  @override
  String get investments_real_estate_name_hint =>
      'Property name (e.g. Lyon 6th apartment)';

  @override
  String get investments_refresh_impossible_title => 'Unable to refresh';

  @override
  String get investments_revert_to_single_value_label =>
      'Revert to single value';

  @override
  String get investments_sector_breakdown_title => 'Sector breakdown';

  @override
  String get investments_sector_placeholder => 'Sector';

  @override
  String get investments_side_label => 'Side';

  @override
  String get investments_size_label => 'Size';

  @override
  String get investments_stop_loss_hint => 'Stop loss (optional)';

  @override
  String get investments_take_profit_hint => 'Take profit (optional)';

  @override
  String get investments_transaction_buy_label => 'Buy';

  @override
  String get investments_transaction_sell_label => 'Sell';

  @override
  String get investments_unlock_date_hint => 'Unlock date';

  @override
  String investments_unlockable_amount(String unlocked, String total) {
    return 'Unlockable: $unlocked of $total';
  }

  @override
  String get investments_unlocked_on_label => 'Unlocked on';

  @override
  String get investments_vesting_cliff_hint => 'Cliff (months, optional)';

  @override
  String get investments_vesting_duration_hint =>
      'Vesting duration (months, optional)';

  @override
  String get investments_wizard_account_title => 'Which account?';

  @override
  String get investments_wizard_add_item_label => 'Add item';

  @override
  String get investments_wizard_asset_class_title => 'Which asset class?';

  @override
  String get investments_wizard_asset_item_title => 'Which item?';

  @override
  String get investments_wizard_asset_label => 'An asset';

  @override
  String get investments_wizard_asset_sublabel =>
      'Real estate, stocks, savings, crypto...';

  @override
  String get investments_wizard_continue_label => 'Continue';

  @override
  String get investments_wizard_create_currency_label => 'Create currency';

  @override
  String get investments_wizard_currency_title => 'Which currency?';

  @override
  String get investments_wizard_establishment_title => 'Which establishment?';

  @override
  String get investments_wizard_investment_or_currency_title =>
      'Which investment or currency?';

  @override
  String get investments_wizard_investment_title => 'Which investment?';

  @override
  String get investments_wizard_item_title => 'Which item?';

  @override
  String get investments_wizard_kind_title => 'What do you want to add?';

  @override
  String get investments_wizard_liability_label => 'A liability';

  @override
  String get investments_wizard_liability_sublabel =>
      'Mortgage, consumer loan...';

  @override
  String get investments_wizard_liability_type_title => 'Which liability type?';

  @override
  String get investments_wizard_new_account_label => 'New account';

  @override
  String get investments_wizard_new_asset_item_label => 'New item';

  @override
  String get investments_wizard_new_currency_label => 'New currency';

  @override
  String get investments_wizard_new_entity_label => 'New entity';

  @override
  String get investments_wizard_new_entity_sublabel =>
      'Holding company, business, SCI, pro account...';

  @override
  String get investments_wizard_new_establishment_label => 'New establishment';

  @override
  String get investments_wizard_new_investment_label => 'New investment';

  @override
  String get investments_wizard_new_investment_or_currency_label =>
      'New investment or currency';

  @override
  String get investments_wizard_new_item_label => 'New item';

  @override
  String get investments_wizard_new_liability_title => 'New liability';

  @override
  String get investments_wizard_no_precise_type => 'No specific type';

  @override
  String get investments_wizard_owner_title => 'Who does this belong to?';

  @override
  String investments_wizard_step_number(String n) {
    return 'Step $n';
  }

  @override
  String investments_wizard_step_of_total(String current, String total) {
    return 'Step $current of $total';
  }

  @override
  String get investments_wizard_step_preliminary => 'Preliminary step';

  @override
  String get investments_wizard_toggle_currency => 'Currency';

  @override
  String get investments_wizard_toggle_investment => 'Investment';

  @override
  String get liabilities_deferral_duration_label =>
      'Deferral duration (months)';

  @override
  String get liabilities_deferral_partial => 'Partial';

  @override
  String get liabilities_deferral_total => 'Full';

  @override
  String get liabilities_deferral_type_label => 'Deferment type';

  @override
  String get liabilities_deferred_loan_label => 'Deferred loan';

  @override
  String get liabilities_down_payment_hint => 'Down payment (€, 0 if none)';

  @override
  String get liabilities_installments_count_label =>
      'Number of installments (months)';

  @override
  String get liabilities_interest_rate_label => 'Interest rate (%)';

  @override
  String get liabilities_loan_type_amortizing => 'Amortizing';

  @override
  String get liabilities_loan_type_in_fine => 'Bullet';

  @override
  String get liabilities_monthly_insurance_label => 'Monthly insurance (€)';

  @override
  String get liabilities_name_hint => 'Name (e.g. Primary residence loan)';

  @override
  String get liabilities_price_total_label => 'Total price (€)';

  @override
  String get liabilities_start_date_label => 'Start date';

  @override
  String get navigation_account_activated => 'Account activated';

  @override
  String get navigation_amounts_hide => 'Hide amounts';

  @override
  String get navigation_amounts_show => 'Show amounts';

  @override
  String get navigation_complete_patrimoine => 'Complete my net worth';

  @override
  String get navigation_export_download_patrimoine_pdf =>
      'Download my net worth (PDF)';

  @override
  String get navigation_export_tooltip => 'Export';

  @override
  String get navigation_export_transactions_csv_json =>
      'Export transactions (JSON/CSV)';

  @override
  String navigation_profile_active_toast_title(Object name) {
    return 'Active profile: $name';
  }

  @override
  String get navigation_vault_activate_failed_toast_title =>
      'Unable to activate this vault';

  @override
  String navigation_vault_active_toast_title(Object name) {
    return 'Active vault: $name';
  }

  @override
  String get navigation_vault_fallback_label => 'Vault';

  @override
  String get navigation_vault_next => 'Next vault';

  @override
  String navigation_vault_next_named(Object name) {
    return 'Next vault: $name';
  }

  @override
  String get navigation_vault_previous => 'Previous vault';

  @override
  String navigation_vault_previous_named(Object name) {
    return 'Previous vault: $name';
  }

  @override
  String get navigation_vault_switched_toast_subtitle =>
      'Switched from account switcher';

  @override
  String notifications_crypto_alert_24h(String symbol, String change) {
    return '$symbol $change% in 24h';
  }

  @override
  String notifications_crypto_price_line(String name, String price) {
    return '$name · $price €';
  }

  @override
  String get notifications_empty => 'No news for now.';

  @override
  String notifications_news_publisher_line(String publisher, String time) {
    return '$publisher · $time';
  }

  @override
  String notifications_relative_days(int days) {
    return '${days}d ago';
  }

  @override
  String notifications_relative_hours(int hours) {
    return '${hours}h ago';
  }

  @override
  String notifications_relative_minutes(int minutes) {
    return '${minutes}min ago';
  }

  @override
  String get notifications_relative_now => 'just now';

  @override
  String get notifications_title => 'News';

  @override
  String onboarding_change_folder_failed(String error) {
    return 'Unable to change folder: $error';
  }

  @override
  String get onboarding_change_vault_folder => 'Change vault folder';

  @override
  String get onboarding_choose_password => 'Choose a password.';

  @override
  String get onboarding_confirm_new_password => 'Confirm new password';

  @override
  String onboarding_create_folder_failed(String error) {
    return 'Unable to create the data folder: $error';
  }

  @override
  String get onboarding_creating => 'Creating...';

  @override
  String get onboarding_description =>
      'Choose where your data will be stored. You can start locally and move this folder to a cloud service (iCloud, Google Drive, Dropbox...) later.';

  @override
  String get onboarding_forgot_password => 'Forgot password?';

  @override
  String get onboarding_migration_interrupted_continue =>
      'I understand, continue anyway';

  @override
  String get onboarding_migration_interrupted_description =>
      'An encryption or decryption operation on this vault was interrupted before it finished (the app may have been closed during the operation). Some private files may have remained in a previous state while others are already up to date.';

  @override
  String get onboarding_migration_interrupted_recommendation =>
      'Recommended: restart the operation from Settings (Enable/Disable encryption) once you are informed — it will bring all files to the same state. If a specific file then refuses to load, it will be a sign that it needs to be restored from a backup.';

  @override
  String get onboarding_migration_interrupted_title => 'Encryption interrupted';

  @override
  String get onboarding_new_password => 'New password';

  @override
  String get onboarding_password => 'Password';

  @override
  String get onboarding_password_incorrect => 'Incorrect password.';

  @override
  String get onboarding_passwords_mismatch => 'The two passwords do not match.';

  @override
  String get onboarding_pick_location => 'Choose a location';

  @override
  String get onboarding_recovery_description =>
      'Enter the recovery key you received when encryption was enabled.';

  @override
  String get onboarding_recovery_key_hint =>
      'Recovery key (e.g. XXXX-XXXX-XXXX-XXXX)';

  @override
  String get onboarding_recovery_key_incorrect => 'Incorrect recovery key.';

  @override
  String get onboarding_recovery_new_password_description =>
      'Your recovery key is valid. Choose a new password for this vault.';

  @override
  String get onboarding_recovery_new_password_title => 'New password';

  @override
  String get onboarding_recovery_saving => 'Saving...';

  @override
  String get onboarding_recovery_set_and_unlock => 'Set and unlock';

  @override
  String get onboarding_recovery_title => 'Vault recovery';

  @override
  String get onboarding_recovery_validate_key => 'Validate key';

  @override
  String get onboarding_recovery_verifying => 'Verifying...';

  @override
  String get onboarding_selecting => 'Selecting...';

  @override
  String get onboarding_unlock => 'Unlock';

  @override
  String get onboarding_unlock_description =>
      'This vault is encrypted. Enter your password to access your data.';

  @override
  String get onboarding_unlocking => 'Unlocking...';

  @override
  String get onboarding_vault_kind_prompt => 'This vault is...';

  @override
  String get onboarding_welcome_title => 'Welcome to Opime';

  @override
  String patrimoine_export_failed_subtitle(String error) {
    return 'The PDF could not be generated or saved: $error';
  }

  @override
  String get patrimoine_export_generate_pdf => 'Generate PDF';

  @override
  String get patrimoine_export_save_dialog_title => 'Save net worth (PDF)';

  @override
  String get patrimoine_export_subtitle =>
      'Select assets and liabilities to include in the PDF.';

  @override
  String patrimoine_export_success_subtitle(String path) {
    return 'The PDF has been saved: $path';
  }

  @override
  String get patrimoine_export_title => 'Download my net worth';

  @override
  String get real_estate_add_document_title => 'Add a document';

  @override
  String get real_estate_add_rent_period_button => 'Add a period';

  @override
  String get real_estate_add_work_item_button => 'Add an item';

  @override
  String get real_estate_add_work_item_title => 'Add a work item';

  @override
  String get real_estate_amount_due_label => 'Amount due (rent + charges)';

  @override
  String get real_estate_amount_received_label => 'Amount received';

  @override
  String get real_estate_annual_charges_not_tracked_note =>
      'Annual charges (property tax, insurance, management...) not yet tracked: net yield equals gross yield.';

  @override
  String get real_estate_annual_rental_income_label => 'Annual rental income';

  @override
  String get real_estate_cashflow_no_loan_note =>
      'No linked loan (see above): cash flow calculated for cash purchase, without loan repayment.';

  @override
  String real_estate_cashflow_with_loan_note(String amount) {
    return 'Loan repayment deducted: $amount.';
  }

  @override
  String get real_estate_continue_button => 'Continue';

  @override
  String get real_estate_create_mortgage_loan => 'Create a mortgage';

  @override
  String get real_estate_create_work_loan => 'Create a work loan';

  @override
  String get real_estate_delete_document_message =>
      'The file will be permanently deleted from the vault.';

  @override
  String real_estate_delete_document_title(String fileName) {
    return 'Delete \"$fileName\"?';
  }

  @override
  String real_estate_delete_rent_period_message(String period) {
    return 'The period $period will be permanently removed from the rent history.';
  }

  @override
  String get real_estate_delete_rent_period_title => 'Delete this period?';

  @override
  String get real_estate_delete_work_item_message =>
      'This work item will be permanently removed.';

  @override
  String real_estate_delete_work_item_title(String label) {
    return 'Delete \"$label\"?';
  }

  @override
  String get real_estate_document_category_invoice => 'Invoice';

  @override
  String get real_estate_document_category_other => 'Other';

  @override
  String get real_estate_document_category_photo => 'Photo';

  @override
  String get real_estate_document_category_plan => 'Plan';

  @override
  String get real_estate_document_category_receipt => 'Receipt';

  @override
  String get real_estate_document_name_hint => 'Document name (optional)';

  @override
  String real_estate_documents_filter_all(int count) {
    return 'All ($count)';
  }

  @override
  String get real_estate_documents_title => 'Documents';

  @override
  String get real_estate_gross_yield_label => 'Gross yield';

  @override
  String get real_estate_link_existing_loan => 'Link an existing loan';

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
    return 'Mark $period as paid';
  }

  @override
  String get real_estate_month_label => 'Month';

  @override
  String real_estate_monthly_cashflow_label(String amount) {
    return 'Monthly cash flow: $amount';
  }

  @override
  String get real_estate_net_yield_label => 'Net yield';

  @override
  String get real_estate_no_documents_yet => 'No documents yet.';

  @override
  String get real_estate_no_rent_periods_yet => 'No rent periods tracked yet.';

  @override
  String get real_estate_no_work_items_yet => 'No work items yet.';

  @override
  String get real_estate_not_self_financed => 'Not self-financed';

  @override
  String get real_estate_note_optional_label => 'Note (optional)';

  @override
  String get real_estate_payment_date_label => 'Payment date';

  @override
  String get real_estate_pricing_address_search_placeholder =>
      'Search for an address...';

  @override
  String get real_estate_pricing_heatmap_loading_communes =>
      'Loading visible communes...';

  @override
  String real_estate_pricing_heatmap_loading_department_prices(
    int loaded,
    int total,
  ) {
    return 'Loading department prices: $loaded / $total (cached, next opening will be instant)';
  }

  @override
  String get real_estate_pricing_heatmap_loading_grid => 'Loading fine grid...';

  @override
  String real_estate_pricing_heatmap_neighborhood_tooltip_title(int size) {
    return 'Neighborhood (~$size m)';
  }

  @override
  String get real_estate_pricing_heatmap_no_data => 'No data';

  @override
  String get real_estate_pricing_heatmap_rent_commune_only =>
      'Rent is only available at the commune level (native granularity of the source).';

  @override
  String real_estate_pricing_heatmap_sale_count(int count) {
    return '$count sale(s)';
  }

  @override
  String get real_estate_profitability_no_rent_hint =>
      'Add rent periods (Rent tab) to calculate the profitability of this property.';

  @override
  String get real_estate_rent_paid => 'Paid';

  @override
  String get real_estate_rent_periods_title => 'Rent';

  @override
  String get real_estate_rent_unpaid => 'Unpaid';

  @override
  String get real_estate_self_financed => 'Self-financed';

  @override
  String get real_estate_tenant_optional_label => 'Tenant (optional)';

  @override
  String get real_estate_total_project_cost_label => 'Total project cost';

  @override
  String get real_estate_work_category_electrical => 'Electrical';

  @override
  String get real_estate_work_category_furniture => 'Furniture';

  @override
  String get real_estate_work_category_other => 'Other';

  @override
  String get real_estate_work_category_paint => 'Paint';

  @override
  String get real_estate_work_category_plumbing => 'Plumbing';

  @override
  String get real_estate_work_category_structural => 'Structural';

  @override
  String get real_estate_work_item_amount_label => 'Amount';

  @override
  String get real_estate_work_item_category_optional_label =>
      'Category (optional)';

  @override
  String get real_estate_work_item_label_field => 'Label';

  @override
  String get real_estate_work_item_label_hint => 'E.g.: Roof repair';

  @override
  String real_estate_work_items_included_note(String amount) {
    return 'Including $amount in work (Work tab).';
  }

  @override
  String get real_estate_work_items_title => 'Work';

  @override
  String real_estate_work_items_total_label(String amount) {
    return 'Total: $amount';
  }

  @override
  String get search_category_enveloppe => 'Envelopes';

  @override
  String get search_category_fondamentaux => 'Fundamentals';

  @override
  String get search_category_formation => 'Training';

  @override
  String get search_category_page => 'Pages';

  @override
  String get search_category_patrimoine => 'Net Worth';

  @override
  String get search_category_vocabulaire => 'Vocabulary';

  @override
  String get search_no_results => 'No results';

  @override
  String get search_placeholder => 'Search in Opime...';

  @override
  String get settings_encryption_confirm_password => 'Confirm password';

  @override
  String get settings_encryption_continue => 'Continue';

  @override
  String get settings_encryption_dont_close_app =>
      'Do not close the application during this operation (window closing is blocked until it completes).';

  @override
  String get settings_encryption_enable_description =>
      'Choose a password to encrypt the private data of this vault (accounts, budget, liabilities, projects, strategy notes, simulations). It will be asked again at each app launch.';

  @override
  String get settings_encryption_encrypting_progress_label =>
      'Encrypting data...';

  @override
  String settings_encryption_files_progress(int done, int total) {
    return '$done / $total file(s)';
  }

  @override
  String get settings_encryption_preparing => 'Preparing...';

  @override
  String get settings_encryption_recovery_key_confirmed_checkbox =>
      'I have saved this key in a safe place';

  @override
  String get settings_encryption_recovery_key_description =>
      'Save it in a safe place (password manager, paper...). It allows you to reset your password if you forget it — without it, your data is permanently lost. It will never be displayed again.';

  @override
  String get settings_encryption_recovery_key_title => 'Your recovery key';

  @override
  String get settings_tax_abattement_conjoint_label =>
      'Spouse/PACS partner (€)';

  @override
  String get settings_tax_abattement_enfant_label => 'Child (€)';

  @override
  String get settings_tax_abattement_petit_enfant_label => 'Grandchild (€)';

  @override
  String get settings_tax_abattements_title => 'Allowances';

  @override
  String get settings_tax_bareme_epoux_title =>
      'Scale between spouses or PACS partners';

  @override
  String get settings_tax_bareme_ligne_directe_title =>
      'Direct line scale (parent/child)';

  @override
  String get settings_tax_bracket_beyond => 'Beyond';

  @override
  String get settings_tax_bracket_nue_propriete_percent => 'Bare ownership (%)';

  @override
  String get settings_tax_bracket_rate_percent => 'Rate (%)';

  @override
  String get settings_tax_bracket_upto_eur => 'Up to (€)';

  @override
  String get settings_tax_bracket_upto_years => 'Up to (years)';

  @override
  String get settings_tax_demembrement_description =>
      'Tax scale for usufruct based on the age of the usufructuary (article 669 CGI) — see the Simulation → Transmission page, Split ownership tab.';

  @override
  String get settings_tax_demembrement_title =>
      'Split ownership (usufruct / bare ownership)';

  @override
  String get settings_tax_donation_description =>
      'Gift and inheritance tax scales (article 777 CGI) and allowances by family relationship — see the Simulation → Transmission page, Split ownership/Donation/Inheritance tabs.';

  @override
  String get settings_tax_donation_title => 'Donation and inheritance';

  @override
  String get settings_tax_ifi_description =>
      'Rate scale by brackets of net real estate wealth (article 977 CGI) and threshold below which IFI is not due at all.';

  @override
  String get settings_tax_ifi_threshold_label =>
      'Tax threshold (€) — total exemption below';

  @override
  String get settings_tax_ifi_title => 'IFI (real estate wealth tax)';

  @override
  String get settings_tax_ir_description =>
      'Progressive rate scale per family quotient share (article 197 CGI) — see the Simulation → Taxation page, Income tax tab.';

  @override
  String get settings_tax_ir_title => 'Income tax';

  @override
  String get settings_tax_page_description =>
      'Rates, thresholds and allowances used by the simulators (income tax, IFI, split ownership, donation and inheritance). Edit a value here if the State revises it, without waiting for a software update — each can be individually reset to its known legal reference via the ↺ icon that appears next to a modified value.';

  @override
  String get settings_tax_pfu_description =>
      '\"Flat tax\" on capital income and capital gains, broken down into its income tax part and its social contributions part — the State can revise one without the other (e.g. social contributions went from 15.5% to 17.2% in 2018, then to 18.6% in early 2026, without touching the income tax rate). Reference values only for now: no app simulator uses them in a calculation yet.';

  @override
  String get settings_tax_pfu_ir_label => 'Income tax part (%)';

  @override
  String get settings_tax_pfu_ps_label => 'Social contributions part (%)';

  @override
  String get settings_tax_pfu_title => 'PFU (flat tax)';

  @override
  String get settings_tax_reset_to_legal_value => 'Reset to legal value';

  @override
  String get simulations_loan_application_fees_label => 'Application fees';

  @override
  String simulations_loan_capital_repaid_at_maturity(String amount) {
    return 'Capital repaid in a lump sum at maturity: $amount';
  }

  @override
  String get simulations_loan_chart_average_monthly_payment =>
      'average monthly payment';

  @override
  String get simulations_loan_chart_capital => 'Capital';

  @override
  String get simulations_loan_chart_insurance => 'Insurance';

  @override
  String get simulations_loan_chart_interest => 'Interest';

  @override
  String get simulations_loan_chart_today => 'Today';

  @override
  String simulations_loan_chart_year_label(int year) {
    return 'Year $year';
  }

  @override
  String get simulations_loan_deferral_duration_label => 'Deferral duration';

  @override
  String get simulations_loan_deferral_label => 'Repayment deferral';

  @override
  String get simulations_loan_deferral_partial => 'Partial moratorium';

  @override
  String get simulations_loan_deferral_partial_explanation =>
      'Only interest is paid during the deferral; the principal remains unchanged.';

  @override
  String get simulations_loan_deferral_total => 'Full moratorium';

  @override
  String get simulations_loan_deferral_total_explanation =>
      'No payment during the deferral; interest is added to the outstanding principal.';

  @override
  String simulations_loan_derived_borrowed_amount(String amount) {
    return 'Borrowed amount (derived): $amount';
  }

  @override
  String get simulations_loan_disclaimer =>
      'Indicative loan simulation: results are based on simplified assumptions (constant rate, linear insurance, fixed fees). Actual bank conditions, guarantees, and contractual terms may change the total cost of credit.';

  @override
  String get simulations_loan_down_payment_label => 'Down payment';

  @override
  String simulations_loan_during_deferral_monthly_payment(String amount) {
    return 'During deferral: $amount/mo';
  }

  @override
  String get simulations_loan_guarantee_fees_label => 'Guarantee fees';

  @override
  String get simulations_loan_including_insurance => 'Including insurance';

  @override
  String get simulations_loan_interest_rate_label => 'Interest rate';

  @override
  String get simulations_loan_monthly_insurance_label => 'Monthly insurance';

  @override
  String get simulations_loan_monthly_payments_label => 'Monthly payments';

  @override
  String get simulations_loan_per_month_suffix => 'mo';

  @override
  String get simulations_loan_project_amount_label => 'Project amount';

  @override
  String get simulations_loan_repayment_duration_label => 'Repayment duration';

  @override
  String get simulations_loan_reset_parameters => 'Reset parameters';

  @override
  String get simulations_loan_suffix_eur_per_month => '€/mo';

  @override
  String get simulations_loan_suffix_months => 'months';

  @override
  String get simulations_loan_suffix_years => 'years';

  @override
  String get simulations_loan_summary_monthly_payment_is =>
      ', your monthly payment is ';

  @override
  String get simulations_loan_summary_over => ' over ';

  @override
  String get simulations_loan_summary_prefix => 'For a loan of ';

  @override
  String get simulations_loan_total_cost_incl_fees_label =>
      'Total cost (incl. fees)';

  @override
  String get simulations_loan_total_credit_cost_label => 'Total credit cost';

  @override
  String get simulations_loan_type_amortizing => 'Amortizing';

  @override
  String get simulations_loan_type_infine => 'Bullet';

  @override
  String get simulations_loan_type_label => 'Loan type';

  @override
  String get simulations_real_estate_tab_estimation => 'Estimation';

  @override
  String get simulations_real_estate_tab_loan => 'Loan';

  @override
  String get simulations_real_estate_tab_scoring => 'Scoring';

  @override
  String get simulations_scoring_age_label => 'Age';

  @override
  String get simulations_scoring_bank_history_label => 'Bank history';

  @override
  String get simulations_scoring_bank_history_none_1y =>
      'No incidents (< 1 yr)';

  @override
  String get simulations_scoring_bank_history_none_3y =>
      'No incidents (≥ 3 yrs)';

  @override
  String get simulations_scoring_bank_history_none_6m =>
      'No incidents (< 6 mo)';

  @override
  String get simulations_scoring_bank_history_one_6m => '1 incident (< 6 mo)';

  @override
  String get simulations_scoring_bank_history_several_6m =>
      'Several incidents (< 6 mo)';

  @override
  String get simulations_scoring_debt_ratio_label => 'Debt ratio';

  @override
  String get simulations_scoring_disclaimer =>
      'Educational and indicative estimate: the scoring grid used here is a common simplification of standard bank criteria, not the benchmark of any specific institution. A bank\'s actual scoring takes many more factors into account (collateral, assets, current internal policy…).';

  @override
  String get simulations_scoring_disposable_income_label => 'Disposable income';

  @override
  String simulations_scoring_disposable_income_value(int value) {
    return '$value €/yr';
  }

  @override
  String simulations_scoring_duration_years_fractional(String years) {
    return '$years yrs';
  }

  @override
  String get simulations_scoring_household_monthly_income_label =>
      'Household monthly income';

  @override
  String get simulations_scoring_income_charges_section_label =>
      'Income & expenses';

  @override
  String get simulations_scoring_income_seniority_label => 'Income seniority';

  @override
  String get simulations_scoring_income_stability_label => 'Income stability';

  @override
  String get simulations_scoring_monthly_expenses_label =>
      'Monthly expenses (excl. mortgage)';

  @override
  String get simulations_scoring_monthly_savings_label => 'Monthly savings';

  @override
  String get simulations_scoring_mortgage_payment_label => 'Mortgage payment';

  @override
  String simulations_scoring_overall_profile_label(String tier) {
    return '$tier profile';
  }

  @override
  String get simulations_scoring_prefilled_from_loan_tab =>
      'Pre-filled from the Loan tab until modified here.';

  @override
  String get simulations_scoring_profession_employee => 'Employee';

  @override
  String get simulations_scoring_profession_executive => 'Executive';

  @override
  String get simulations_scoring_profession_executive_senior =>
      'Senior executive';

  @override
  String get simulations_scoring_profession_label => 'Profession';

  @override
  String get simulations_scoring_profession_unemployed => 'Unemployed';

  @override
  String get simulations_scoring_profession_worker => 'Worker';

  @override
  String get simulations_scoring_profile_section_label => 'Profile';

  @override
  String get simulations_scoring_savings_effort_label => 'Savings effort';

  @override
  String get simulations_scoring_suffix_shares => 'shares';

  @override
  String get simulations_scoring_tax_shares_label => 'Tax shares';

  @override
  String get simulations_scoring_tier_average => 'Average';

  @override
  String get simulations_scoring_tier_critical => 'Critical';

  @override
  String get simulations_scoring_tier_excellent => 'Excellent';

  @override
  String get simulations_scoring_tier_good => 'Good';

  @override
  String get simulations_scoring_tier_poor => 'Poor';

  @override
  String simulations_scoring_total_points(int points) {
    return '$points / 35 points';
  }

  @override
  String get transactions_export_deselect_all => 'Deselect all';

  @override
  String get transactions_export_empty => 'No transactions to export yet.';

  @override
  String transactions_export_failed_subtitle(String error) {
    return 'The file could not be generated or saved: $error';
  }

  @override
  String get transactions_export_failed_title => 'Export failed';

  @override
  String get transactions_export_save_dialog_title => 'Save transactions';

  @override
  String get transactions_export_select_all => 'Select all';

  @override
  String get transactions_export_subtitle => 'Select accounts to include.';

  @override
  String transactions_export_success_subtitle(String path) {
    return 'The file has been saved: $path';
  }

  @override
  String get transactions_export_success_title => 'Export successful';

  @override
  String get transactions_export_title => 'Export my transactions';

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
    return 'A new version of Opime is available ($version).';
  }

  @override
  String get nav_assets_actions_funds => 'Stocks & Funds';

  @override
  String get nav_assets_private_equity => 'Private Equity';

  @override
  String get nav_assets_real_estate => 'Real estate';

  @override
  String get nav_assets_crypto => 'Crypto';

  @override
  String get nav_assets_precious_metals => 'Precious metals';

  @override
  String get nav_assets_savings => 'Savings';

  @override
  String get nav_assets_other => 'Other';

  @override
  String get nav_liabilities_loans => 'Loans';

  @override
  String get nav_liabilities_mortgages => 'Real estate loans';

  @override
  String get nav_investment => 'Fundamentals';

  @override
  String get nav_invest_why => 'Why invest?';

  @override
  String get nav_invest_inflation => 'Inflation';

  @override
  String get nav_invest_risk => 'Risk';

  @override
  String get nav_invest_diversification => 'Diversification';

  @override
  String get nav_invest_etf => 'ETFs';

  @override
  String get nav_invest_fees => 'Fees';

  @override
  String get nav_invest_taxation => 'Taxation';

  @override
  String get nav_invest_pyramid => 'Investment pyramid';

  @override
  String get nav_invest_allocation => 'Strategic/dynamic allocation';

  @override
  String get nav_invest_long_term => 'The long term';

  @override
  String get nav_envelopes => 'Tax wrappers';

  @override
  String get nav_envelope_current_account => 'Current account';

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
  String get nav_envelope_life_insurance => 'Life insurance';

  @override
  String get nav_envelope_capitalization_contract => 'Capitalization contract';

  @override
  String get nav_envelope_pee_peg => 'PEE / PEG';

  @override
  String get nav_envelope_per => 'PER';

  @override
  String get nav_training => 'Training';

  @override
  String get nav_training_stock_market => 'Stock market';

  @override
  String get nav_training_precious_metals => 'Precious metals';

  @override
  String get nav_training_crypto => 'Crypto';

  @override
  String get nav_training_real_estate => 'Real estate';

  @override
  String get nav_training_wealth_structuring => 'Wealth structuring';

  @override
  String get simulations_wealth_tab_compound_interest => 'Compound interest';

  @override
  String get simulations_wealth_tab_deterministic_compound_interest =>
      'Deterministic (Compound interest)';

  @override
  String get simulations_wealth_tab_monte_carlo => 'Monte-Carlo';

  @override
  String get simulations_wealth_tab_stochastic_monte_carlo =>
      'Stochastic (Monte-Carlo)';

  @override
  String get simulations_wealth_simple_disclaimer =>
      'Indicative deterministic projection based on constant returns and simplified tax rules. \"Current purchasing power\" values discount the nominal result using the entered inflation rate (real value = nominal value / (1 + inflation)^years). Markets, fees, actual taxes, and life events may significantly alter the results.';

  @override
  String get simulations_wealth_monte_carlo_disclaimer =>
      'Indicative Monte-Carlo simulation: the chosen distributions and volatility assumptions are simplified. Percentiles are neither a performance guarantee nor an investment recommendation.';

  @override
  String get simulations_wealth_current_assets => 'Current assets';

  @override
  String get simulations_wealth_initial_asset_allocation =>
      'Initial asset allocation';

  @override
  String get simulations_wealth_stock => 'Stocks';

  @override
  String get simulations_wealth_other => 'Other';

  @override
  String get simulations_wealth_monthly_investments => 'Monthly investments';

  @override
  String get simulations_wealth_investment_allocation =>
      'Investment allocation';

  @override
  String get simulations_wealth_savings_years => 'Number of savings years';

  @override
  String get simulations_wealth_stock_return => 'Stock return';

  @override
  String get simulations_wealth_other_return => 'Other return';

  @override
  String get simulations_wealth_stock_tax => 'Stock tax';

  @override
  String get simulations_wealth_other_tax => 'Other tax';

  @override
  String get simulations_wealth_withdrawal_rate => 'Withdrawal rate';

  @override
  String get simulations_wealth_inflation_rate => 'Inflation rate';

  @override
  String get simulations_wealth_reset_parameters => 'Reset parameters';

  @override
  String simulations_wealth_net_value_in_n_years(int count) {
    return 'Net value in $count years';
  }

  @override
  String get simulations_wealth_passive_income_prefix =>
      'i.e. a passive income of around ';

  @override
  String get simulations_wealth_initial_assets => 'Initial assets';

  @override
  String get simulations_wealth_contributions => 'Contributions';

  @override
  String get simulations_wealth_net_interest => 'Net interest';

  @override
  String get simulations_wealth_stat_future_value => 'Future value';

  @override
  String get simulations_wealth_stat_included_capital_gains =>
      'Including capital gains';

  @override
  String get simulations_wealth_stat_net_value => 'Net value';

  @override
  String get simulations_wealth_stat_monthly_income => 'Monthly income';

  @override
  String get simulations_wealth_stat_net_value_purchasing_power =>
      'Net value (current purchasing power)';

  @override
  String get simulations_wealth_stat_monthly_income_purchasing_power =>
      'Monthly income (current purchasing power)';

  @override
  String get simulations_wealth_chart_today => 'Today';

  @override
  String simulations_wealth_chart_in_n_years(int count) {
    return 'In $count years';
  }

  @override
  String simulations_wealth_chart_n_years(int count) {
    return '$count years';
  }

  @override
  String get simulations_wealth_avg_stock_return => 'Avg. stock return';

  @override
  String get simulations_wealth_stock_std_dev => 'Stock std. deviation';

  @override
  String get simulations_wealth_avg_other_return => 'Avg. other return';

  @override
  String get simulations_wealth_other_std_dev => 'Other std. deviation';

  @override
  String get simulations_wealth_number_of_simulations =>
      'Number of simulations';

  @override
  String simulations_wealth_median_net_value_in_n_years(int count) {
    return 'Median net value in $count years';
  }

  @override
  String get simulations_wealth_median_passive_income_prefix =>
      'i.e. a median passive income of around ';

  @override
  String simulations_wealth_between_p10_and_p90(String p10, String p90) {
    return 'Between $p10 and $p90 across scenarios (10th-90th percentile)';
  }

  @override
  String get simulations_wealth_median_net_interest => 'Median (net interest)';

  @override
  String get simulations_wealth_stat_median_future_value =>
      'Median future value';

  @override
  String get simulations_wealth_stat_median_included_capital_gains =>
      'Including median capital gains';

  @override
  String get simulations_wealth_stat_median_net_value => 'Median net value';

  @override
  String get simulations_wealth_stat_median_monthly_income =>
      'Median monthly income';

  @override
  String get simulations_wealth_median_label => 'Median';

  @override
  String get simulations_wealth_90th_percentile => '90th percentile';

  @override
  String get simulations_wealth_10th_percentile => '10th percentile';

  @override
  String get simulations_transmission_demembrement => 'Usufruct';

  @override
  String get simulations_transmission_donation => 'Gift';

  @override
  String get simulations_transmission_heritage => 'Inheritance';

  @override
  String get simulations_transmission_value_full_property =>
      'Full ownership value';

  @override
  String get simulations_transmission_usufruitier_age => 'Usufructuary age';

  @override
  String get simulations_transmission_number_beneficiary_children =>
      'Number of beneficiary children';

  @override
  String get simulations_transmission_abatement_per_child_remaining =>
      'Allowance per child (remaining)';

  @override
  String get simulations_transmission_reset_parameters => 'Reset parameters';

  @override
  String get simulations_transmission_projection_demembrement =>
      'Usufruct rights projection';

  @override
  String get simulations_transmission_hypothesis_2026_nue =>
      '2026 assumption: bare ownership ';

  @override
  String get simulations_transmission_usufruit_separator => ' / usufruct ';

  @override
  String get simulations_transmission_scenario_comparison =>
      'Scenario comparison';

  @override
  String get simulations_transmission_full_property_rights =>
      'Full ownership rights';

  @override
  String get simulations_transmission_demembrement_rights => 'Usufruct rights';

  @override
  String get simulations_transmission_potential_savings => 'Potential savings';

  @override
  String get simulations_transmission_np_value => 'BO value';

  @override
  String get simulations_transmission_np_taxable_per_child =>
      'Taxable BO / child';

  @override
  String get simulations_transmission_np_rights_per_child =>
      'Rights BO / child';

  @override
  String get simulations_transmission_full_property_rights_if =>
      'Rights if full ownership';

  @override
  String get simulations_transmission_demembrement_rights_detail =>
      'Rights under usufruct';

  @override
  String get simulations_transmission_donation_amount => 'Gift amount';

  @override
  String get simulations_transmission_number_beneficiaries =>
      'Number of beneficiaries';

  @override
  String get simulations_transmission_donor_donee_link =>
      'Donor / donee relationship';

  @override
  String get simulations_transmission_child => 'Child';

  @override
  String get simulations_transmission_grandchild => 'Grandchild';

  @override
  String get simulations_transmission_spouse_pacs => 'Spouse / PACS partner';

  @override
  String simulations_transmission_abatement_per_beneficiary(String amount) {
    return 'Allowance applied: $amount / beneficiary';
  }

  @override
  String get simulations_transmission_estimated_donation_rights =>
      'Estimated gift tax';

  @override
  String get simulations_transmission_effective_rate_prefix =>
      'Effective rate ';

  @override
  String get simulations_transmission_effective_rate_suffix =>
      ' on the transferred amount.';

  @override
  String get simulations_transmission_tax_breakdown => 'Tax breakdown';

  @override
  String get simulations_transmission_total_amount_transferred =>
      'Total amount transferred';

  @override
  String get simulations_transmission_total_taxable_base =>
      'Total taxable base';

  @override
  String get simulations_transmission_total_rights => 'Total rights';

  @override
  String get simulations_transmission_amount_per_beneficiary =>
      'Amount / beneficiary';

  @override
  String get simulations_transmission_taxable_per_beneficiary =>
      'Taxable / beneficiary';

  @override
  String get simulations_transmission_rights_per_beneficiary =>
      'Rights / beneficiary';

  @override
  String get simulations_transmission_estimated_inheritance_rights =>
      'Estimated inheritance tax';

  @override
  String get simulations_transmission_estate_breakdown => 'Estate breakdown';

  @override
  String get simulations_transmission_spouse_exempt_part =>
      'Spouse exempt share';

  @override
  String get simulations_transmission_children_mass => 'Children\'s mass';

  @override
  String get simulations_transmission_children_total_rights =>
      'Children\'s total rights';

  @override
  String get simulations_transmission_children_transferred_mass =>
      'Mass transferred to children';

  @override
  String get simulations_transmission_gross_part_per_child =>
      'Gross share / child';

  @override
  String get simulations_transmission_taxable_per_child => 'Taxable / child';

  @override
  String get simulations_transmission_rights_per_child => 'Rights / child';

  @override
  String get simulations_transmission_net_per_child => 'Net / child';

  @override
  String get simulations_transmission_surviving_spouse => 'Surviving spouse';

  @override
  String get simulations_transmission_spouse_share =>
      'Share allocated to spouse';

  @override
  String get simulations_transmission_number_inheriting_children =>
      'Number of inheriting children';

  @override
  String get simulations_transmission_net_estate_assets => 'Net estate assets';

  @override
  String get simulations_transmission_abatement_per_child =>
      'Allowance per child';

  @override
  String get simulations_transmission_disclaimer_demembrement =>
      'Usufruct/bare ownership valuation schedule per article 669 CGI (2026 reference). Indicative simulation, excluding specific civil clauses, successive usufruct/ownership, and personalised notarial optimisation.';

  @override
  String get simulations_transmission_disclaimer_donation =>
      'Simplified 2026 gift tax schedules. Allowances simulated by kinship, excluding family cash gifts, tax carry-over, specific deductions, or deductible liabilities.';

  @override
  String get simulations_transmission_disclaimer_heritage =>
      'Simplified 2026 inheritance reference: spouse/PACS exempt, direct-line schedule for children. Does not account for detailed civil options (legal usufruct of spouse, available portion, will, life insurance).';

  @override
  String get simulations_estimation_property_address => 'Property address';

  @override
  String get simulations_estimation_price_per_sqm => 'Price per m²';

  @override
  String get simulations_estimation_rent_per_sqm => 'Rent per m²';

  @override
  String get simulations_estimation_property_usage => 'Property usage';

  @override
  String get simulations_estimation_usage_locatif => 'Rental investment';

  @override
  String get simulations_estimation_usage_residence =>
      'Primary/secondary residence';

  @override
  String get simulations_estimation_property_type => 'Property type';

  @override
  String get simulations_estimation_type_maison => 'House';

  @override
  String get simulations_estimation_type_appartement => 'Flat';

  @override
  String get simulations_estimation_field_surface => 'Surface area';

  @override
  String get simulations_estimation_field_price_per_sqm =>
      'Price per m² (adjustable)';

  @override
  String get simulations_estimation_rental_units => 'Rental units';

  @override
  String simulations_estimation_unit_number(int n) {
    return 'Unit $n';
  }

  @override
  String get simulations_estimation_financing => 'Financing';

  @override
  String get simulations_estimation_field_travaux => 'Renovation works';

  @override
  String get simulations_estimation_field_frais_notaire => 'Notary fees';

  @override
  String get simulations_estimation_field_charges_annuelles =>
      'Annual charges (shared costs, property tax, insurance...)';

  @override
  String get simulations_estimation_cash_purchase => 'Cash purchase (no loan)';

  @override
  String simulations_estimation_derived_loan_amount(String amount) {
    return 'Borrowed amount (derived): $amount';
  }

  @override
  String simulations_estimation_loan_info(
    String apport,
    String taux,
    int duree,
    String assurance,
  ) {
    return 'Down payment $apport, rate $taux % over $duree years, insurance $assurance/month — set in the Loan tab.';
  }

  @override
  String get simulations_estimation_use_configured_loan =>
      'Use configured loan';

  @override
  String get simulations_estimation_estimated_price =>
      'Estimated property price';

  @override
  String get simulations_estimation_estimation_in_progress => 'Estimating...';

  @override
  String simulations_estimation_comparable_sales_info(
    int sampleSize,
    String scope,
    String years,
  ) {
    return 'Based on $sampleSize comparable sale(s) $scope, $years.';
  }

  @override
  String get simulations_estimation_no_comparable_sales =>
      'No comparable sales found — adjust the price manually.';

  @override
  String get simulations_estimation_rent_estimation_in_progress =>
      'Estimating rent...';

  @override
  String get simulations_estimation_estimated_rent_label => 'Estimated rent: ';

  @override
  String get simulations_estimation_rent_zone_commune => ' (commune)';

  @override
  String get simulations_estimation_rent_zone_expanded => ' (expanded zone)';

  @override
  String get simulations_estimation_gross_rental_income =>
      'Gross rental income';

  @override
  String get simulations_estimation_net_rental_income => 'Net rental income';

  @override
  String get simulations_estimation_loan_payment => 'Loan payment';

  @override
  String get simulations_estimation_project_self_financed =>
      'Self-financed project';

  @override
  String get simulations_estimation_project_not_self_financed =>
      'Project not self-financed';

  @override
  String simulations_estimation_monthly_cash_flow(String amount) {
    return 'Monthly cash flow: $amount';
  }

  @override
  String get simulations_estimation_gross_yield => 'Gross yield';

  @override
  String get simulations_estimation_net_yield => 'Net yield';

  @override
  String get simulations_estimation_total_project_cost => 'Total project cost';

  @override
  String get simulations_estimation_strategy => 'Strategy';

  @override
  String get simulations_estimation_strategy_long_term => 'Long-term';

  @override
  String get simulations_estimation_strategy_short_term => 'Short-term';

  @override
  String get simulations_estimation_strategy_seasonal_mix => 'Seasonal mix';

  @override
  String get simulations_estimation_strategy_colocation => 'Co-living';

  @override
  String get simulations_estimation_field_monthly_rent => 'Monthly rent (€)';

  @override
  String get simulations_estimation_field_nightly_rate => 'Nightly rate (€)';

  @override
  String get simulations_estimation_field_occupancy => 'Occupancy (%)';

  @override
  String get simulations_estimation_field_long_term_months =>
      'Long-term months';

  @override
  String get simulations_estimation_field_long_term_rent =>
      'Long-term rent (€)';

  @override
  String get simulations_estimation_field_short_term_months =>
      'Short-term months';

  @override
  String get simulations_estimation_field_summer_nightly_rate =>
      'Summer nightly rate (€)';

  @override
  String simulations_estimation_room_number(int n) {
    return 'Room $n';
  }

  @override
  String get simulations_estimation_add_room => '+ Add a room';

  @override
  String get simulations_estimation_unit_default_label => 'Whole property';

  @override
  String get simulations_estimation_whole_township => '(entire township)';

  @override
  String simulations_estimation_within_radius(String kilometers) {
    return 'within a $kilometers km radius';
  }

  @override
  String get simulations_estimation_room_default_label => 'Room 1';

  @override
  String get budget_manage_recurring_tooltip => 'Recurring lines';

  @override
  String get budget_new_category_placeholder => 'New category';

  @override
  String get investments_documents_no_transaction_title => 'No transaction';

  @override
  String get investments_documents_no_transaction_message =>
      'Add a transaction first so you can attach a document to it.';

  @override
  String get investments_documents_link_transaction_label =>
      'Attach to which transaction?';

  @override
  String get investments_documents_empty => 'No documents yet.';

  @override
  String get investments_documents_view_dialog_title => 'Transaction documents';

  @override
  String investments_documents_view_dialog_subtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents — click to open.',
      one: '1 document — click to open.',
    );
    return '$_temp0';
  }

  @override
  String budget_recurring_templates_dialog_title(String sectionTitle) {
    return 'Recurring lines — $sectionTitle';
  }

  @override
  String get budget_recurring_templates_dialog_subtitle =>
      'A reusable starting point, not a living rule: editing a template does not change lines already added in previous months.';

  @override
  String get budget_recurring_templates_empty => 'No recurring line yet.';

  @override
  String get budget_recurring_templates_apply_now => 'Apply now';

  @override
  String get investments_edit_account_menu_item => 'Edit account';

  @override
  String get investments_delete_account_menu_item => 'Delete account';

  @override
  String get investments_delete_account_requires_empty_tooltip =>
      'Empty it first';

  @override
  String get investments_reinclude_in_net_worth_menu_item =>
      'Include in net worth again';

  @override
  String get investments_exclude_from_net_worth_menu_item =>
      'Exclude from net worth';

  @override
  String get investments_import_ibkr_statement_menu_item =>
      'Import a statement (IBKR)';

  @override
  String get investments_tab_positions => 'Positions';

  @override
  String get investments_tab_transactions => 'Transactions';

  @override
  String get investments_show_all_account_toggle_expanded =>
      'Hide the rest of the account';

  @override
  String investments_show_all_account_toggle_collapsed(int count) {
    return 'Show entire account (+$count)';
  }

  @override
  String get projects_new_project => 'New project';

  @override
  String get projects_edit_project => 'Edit project';

  @override
  String get projects_name_placeholder =>
      'Project name (e.g. Buy primary residence)';

  @override
  String get projects_description_placeholder => 'Description (optional)';

  @override
  String get projects_echeance_placeholder => 'Deadline';

  @override
  String get projects_rendement_placeholder => 'Expected return (% / year)';

  @override
  String get projects_apport_mensuel_placeholder =>
      'Monthly contribution in € (optional)';

  @override
  String get projects_montant_cible_placeholder =>
      'Target amount in € (optional)';

  @override
  String get projects_linked_accounts_label => 'Linked accounts';

  @override
  String get projects_linked_liabilities_label => 'Linked liabilities';

  @override
  String get projects_dangling_links_warning =>
      'One or more links no longer resolve (item deleted since).';

  @override
  String get projects_no_accounts_available => 'No accounts available.';

  @override
  String get projects_no_liabilities_available => 'No liabilities available.';

  @override
  String get projects_trajectory_title => 'Projected trajectory';

  @override
  String get projects_stat_rendement_attendu => 'Expected return';

  @override
  String get projects_stat_apport_mensuel => 'Monthly contribution';

  @override
  String get projects_stat_temps_restant => 'Time remaining';

  @override
  String get projects_stat_montant_actuel => 'Current amount';

  @override
  String get projects_stat_reste_a_atteindre => 'Remaining to reach';

  @override
  String get projects_linked_accounts_liabilities_title =>
      'Linked accounts and liabilities';

  @override
  String get projects_echeance_deadline_passed => 'Deadline passed';

  @override
  String get projects_echeance_today => 'Deadline today';

  @override
  String projects_echeance_in_days(int days) {
    return 'In $days days';
  }

  @override
  String projects_echeance_in_months(int months) {
    return 'In $months months';
  }

  @override
  String projects_echeance_in_years(int years) {
    return 'In $years years';
  }

  @override
  String projects_days_count(int days) {
    return '$days days';
  }

  @override
  String get projects_on_track_label => 'On track';

  @override
  String get projects_off_track_label => 'Behind schedule';

  @override
  String get projects_load_error =>
      'Unable to load projects. Check that the Vault folder is accessible.';

  @override
  String get projects_select_or_create => 'Select or create a project';

  @override
  String get projects_empty => 'No projects';

  @override
  String get simulations_taxation_tab_ir => 'IR';

  @override
  String get simulations_taxation_tab_ifi => 'IFI';

  @override
  String get simulations_taxation_tab_pfu => 'PFU';

  @override
  String get simulations_taxation_ifi_disclaimer =>
      'Indicative IFI (real-estate wealth tax) simulation based on a simplified 2026 schedule, excluding specific mechanisms (rebates, particular exemptions, usufruct/bare-ownership cases, income-based capping, etc.). Tax rules change regularly: always check with a professional before making a decision.';

  @override
  String get simulations_taxation_ir_disclaimer =>
      'Indicative income tax simulation with a simplified family quotient. It does not account for every real-life situation (deductible expenses, tax credits/reductions, specific income types, caps, and particular rules). Check the final result with an expert.';

  @override
  String get simulations_taxation_field_ifi_net_worth =>
      'Net real estate worth';

  @override
  String get simulations_taxation_reset_parameters => 'Reset parameters';

  @override
  String get simulations_taxation_ifi_summary_prefix =>
      'This year, you have a net real estate worth of ';

  @override
  String get simulations_taxation_ifi_summary_middle =>
      ', resulting in a total real estate wealth tax (IFI) of ';

  @override
  String get simulations_taxation_summary_equivalent_suffix =>
      ', or the equivalent of ';

  @override
  String get simulations_taxation_legend_amount => 'Amount';

  @override
  String get simulations_taxation_legend_bracket_max => 'Bracket max amount';

  @override
  String get simulations_taxation_legend_tax => 'Tax';

  @override
  String get simulations_taxation_ifi_stat_max_rate => 'Maximum tax rate';

  @override
  String get simulations_taxation_ifi_stat_total_monthly =>
      'IFI (total & monthly)';

  @override
  String get simulations_taxation_pfu_field_envelope => 'Envelope';

  @override
  String get simulations_taxation_pfu_field_data_source => 'Data source';

  @override
  String get simulations_taxation_pfu_mode_manual => 'Manual entry';

  @override
  String get simulations_taxation_pfu_mode_existing_account =>
      'Existing account';

  @override
  String get simulations_taxation_pfu_field_choose_account =>
      'Choose an account';

  @override
  String get simulations_taxation_pfu_select_account_placeholder => 'Select…';

  @override
  String simulations_taxation_pfu_no_account_found(String envelope) {
    return 'No $envelope account found in your net worth.';
  }

  @override
  String get simulations_taxation_pfu_field_opening_date =>
      'Account opening date';

  @override
  String get simulations_taxation_field_invested_amount => 'Invested amount';

  @override
  String get simulations_taxation_field_current_value => 'Current value';

  @override
  String get simulations_taxation_field_withdrawal_amount =>
      'Withdrawal amount';

  @override
  String simulations_taxation_pfu_summary_withdrawal_exempt_prefix(
    String envelope,
  ) {
    return '$envelope withdrawal after 5 years: ';
  }

  @override
  String simulations_taxation_pfu_summary_withdrawal_prefix(String envelope) {
    return '$envelope withdrawal: ';
  }

  @override
  String get simulations_taxation_pfu_summary_tax_exempt => 'tax-exempt';

  @override
  String get simulations_taxation_pfu_summary_gain_prefix => 'gain of ';

  @override
  String get simulations_taxation_pfu_summary_pfu_tax_prefix => ', PFU tax of ';

  @override
  String get simulations_taxation_pfu_summary_net_received_prefix =>
      ', net received ';

  @override
  String get simulations_taxation_pfu_exempt_message =>
      'Your withdrawal is fully tax-exempt.';

  @override
  String get simulations_taxation_pfu_exempt_explanation =>
      'PEA gains are exempt from income tax and social contributions after 5 years of holding.';

  @override
  String get simulations_taxation_pfu_stat_unrealized_gain => 'Unrealized gain';

  @override
  String get simulations_taxation_pfu_stat_taxable_gain => 'Taxable gain';

  @override
  String simulations_taxation_pfu_stat_ir_rate(String rate) {
    return 'IR (PFU $rate%)';
  }

  @override
  String simulations_taxation_pfu_stat_ps_rate(String rate) {
    return 'PS (PFU $rate%)';
  }

  @override
  String get simulations_taxation_pfu_stat_total => 'Total PFU';

  @override
  String get simulations_taxation_pfu_stat_net_received =>
      'Net amount received';

  @override
  String get simulations_taxation_pfu_comparison_title =>
      'Comparison: PFU vs progressive tax schedule';

  @override
  String get simulations_taxation_pfu_stat_bareme_ir =>
      'Progressive income tax';

  @override
  String get simulations_taxation_pfu_stat_bareme_ps =>
      'Progressive social contributions';

  @override
  String get simulations_taxation_pfu_stat_bareme_total =>
      'Total progressive tax';

  @override
  String get simulations_taxation_pfu_stat_net_after_bareme =>
      'Net after progressive tax';

  @override
  String get simulations_taxation_pfu_wins_label =>
      'The PFU is more advantageous';

  @override
  String get simulations_taxation_bareme_wins_label =>
      'The progressive tax schedule is more advantageous';

  @override
  String simulations_taxation_pfu_comparison_savings(
    String label,
    String amount,
  ) {
    return '$label ($amount in savings)';
  }

  @override
  String get simulations_taxation_pfu_about_title => 'About the PFU (flat tax)';

  @override
  String get simulations_taxation_pfu_about_body =>
      'The PFU is a flat tax of 31.4% (12.8% income tax + 18.6% social contributions) on capital gains from disposals. For a PEA, gains are exempt after 5 years. For a life insurance policy (Assurance-Vie), an annual allowance of €4,600 (€9,200 after 8 years) applies before taxation.';

  @override
  String get simulations_taxation_pfu_about_rates_note =>
      'The rates used come from Settings → Tax parameters and can be customized.';

  @override
  String get simulations_taxation_field_taxable_income => 'Net taxable income';

  @override
  String get simulations_taxation_field_parts => 'Number of tax shares';

  @override
  String get simulations_taxation_ir_summary_prefix =>
      'This year, you have a net taxable income of ';

  @override
  String get simulations_taxation_ir_summary_middle =>
      ', resulting in a total income tax of ';

  @override
  String get simulations_taxation_ir_stat_quotient => 'Family quotient';

  @override
  String get simulations_taxation_ir_stat_marginal_rate => 'Marginal tax rate';

  @override
  String get simulations_taxation_ir_stat_total_monthly =>
      'Income tax (total & monthly)';

  @override
  String simulations_taxation_bracket_tooltip_title(String label) {
    return 'Bracket $label';
  }

  @override
  String get simulations_taxation_bracket_tooltip_max => 'Max amount';

  @override
  String get simulations_taxation_date_day_placeholder => 'DD';

  @override
  String get simulations_taxation_date_month_placeholder => 'MM';

  @override
  String get simulations_taxation_date_year_placeholder => 'YYYY';

  @override
  String get investments_section_title => 'Investments';

  @override
  String get investments_identifier_copied_toast_title => 'Identifier copied';

  @override
  String get investments_ticker_copied_toast_title => 'Ticker copied';

  @override
  String get investments_quantity_units_suffix => 'units';

  @override
  String get investments_add_investment_button => 'Add an investment';

  @override
  String get investments_establishment_select_placeholder =>
      'Institution (bank)';

  @override
  String get investments_clear_opening_date_button => 'Clear the date';

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
  String get strategy_editor_placeholder => 'Write your strategy...';

  @override
  String get strategy_load_error =>
      'Unable to load notes. Check that the Vault folder is accessible.';

  @override
  String get strategy_select_or_create => 'Select or create a note';

  @override
  String get strategy_new_folder_title => 'New folder';

  @override
  String get strategy_rename_folder_title => 'Rename folder';

  @override
  String get strategy_folder_name_placeholder => 'Folder name';

  @override
  String get strategy_folder_color_title => 'Folder color';

  @override
  String strategy_delete_folder_confirm_title(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get strategy_delete_folder_confirm_message =>
      'The notes it contains will not be deleted, only moved back out of the folder.';

  @override
  String get strategy_move_to_folder_title => 'Move to a folder';

  @override
  String get strategy_no_folder_label => 'No folder';

  @override
  String get strategy_duplicate_note_menu_item => 'Duplicate';

  @override
  String get strategy_notes_panel_title => 'Notes';

  @override
  String get strategy_search_placeholder => 'Search a note...';

  @override
  String get strategy_no_notes => 'No notes';

  @override
  String get strategy_change_color_menu_item => 'Change color';

  @override
  String get investments_price_fresh_badge => 'up to date';

  @override
  String get investments_price_manual_badge => 'manual';

  @override
  String investments_manual_price_estimated_on(String date) {
    return 'Estimated on $date';
  }

  @override
  String get investments_excluded_from_patrimoine_badge =>
      'Excluded from total net worth';

  @override
  String investments_documents_attached_tooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attached documents',
      one: '1 attached document',
    );
    return '$_temp0 — view';
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
    return 'Sold $sellQuantity × $sellPrice → Bought $buyQuantity × $buyPrice';
  }

  @override
  String get investments_manual_price_dialog_title => 'Current estimated price';

  @override
  String investments_manual_price_hint_multi_unit(String quantity) {
    return 'Estimated price per unit — update it yourself whenever you see fit, no automatic price source exists for this holding. The displayed value will be this price × $quantity units held.';
  }

  @override
  String get investments_manual_price_hint_single_unit =>
      'Update it yourself whenever you see fit — no automatic price source exists for this holding.';

  @override
  String get investments_field_price_eur => 'Price (€)';

  @override
  String get investments_pe_valuation_dialog_title => 'Current valuation';

  @override
  String get investments_pe_valuation_hint =>
      'Latest NAV/valuation reported by the fund manager — update it yourself when you receive it, no automatic price source exists for this holding.';

  @override
  String get investments_field_valuation_eur => 'Valuation (€)';

  @override
  String investments_delete_position_confirm_title(String label) {
    return 'Delete \"$label\"?';
  }

  @override
  String get investments_delete_position_confirm_message =>
      'This position will be permanently deleted.';

  @override
  String get investments_reestimate_pe_valuation_menu_item =>
      'Re-estimate the valuation';

  @override
  String get investments_reestimate_price_menu_item => 'Re-estimate the price';

  @override
  String get investments_transfer_to_other_account_menu_item =>
      'Transfer to another account';

  @override
  String get investments_arbitrage_to_other_security_menu_item =>
      'Switch to another security';

  @override
  String get investments_merge_with_other_position_menu_item =>
      'Merge with another position';

  @override
  String get investments_delete_position_requires_no_transactions_hint =>
      'Delete its transactions first';

  @override
  String get investments_delete_position_menu_item => 'Delete the position';

  @override
  String get investments_isin_copied_toast => 'ISIN copied';

  @override
  String get investments_identifier_copied_toast => 'Identifier copied';

  @override
  String get investments_ticker_copied_toast => 'Ticker copied';

  @override
  String get investments_stat_net_invested_capital => 'Net capital invested';

  @override
  String get investments_stat_quantity_held => 'Quantity held';

  @override
  String get investments_stat_vested => 'Vested';

  @override
  String get investments_stat_last_price => 'Last price';

  @override
  String get investments_stat_estimated_price => 'Estimated price';

  @override
  String get investments_stat_valuation => 'Valuation';

  @override
  String investments_performance_annualized(String percent) {
    return '$percent / year';
  }

  @override
  String investments_performance_since_start(String percent) {
    return '$percent since inception';
  }

  @override
  String get investments_insufficient_price_history =>
      'Not enough price history for this calculation.';

  @override
  String get investments_insufficient_transaction_history =>
      'Not enough transaction history for this calculation.';

  @override
  String investments_pe_valuation_estimated_on(String date) {
    return 'Valuation estimated on $date (use the \"⋮\" menu to update it).';
  }

  @override
  String get investments_pe_no_valuation_hint =>
      'No valuation provided: the amount above is the net capital invested — use the \"⋮\" menu to enter the latest NAV reported by the manager.';

  @override
  String investments_manual_price_estimated_on_menu_hint(String date) {
    return 'Price estimated on $date (use the \"⋮\" menu to update it).';
  }

  @override
  String get investments_no_manual_price_hint =>
      'No price provided: the valuation above is the net amount invested — use the \"⋮\" menu to add one.';

  @override
  String investments_price_not_found_yahoo(String isin) {
    return 'Price not found on Yahoo Finance for \"$isin\".';
  }

  @override
  String get investments_price_not_available_yet =>
      'Real-time price not yet available: the valuation above is the net amount invested.';

  @override
  String get investments_no_positions_yet => 'No positions yet.';

  @override
  String get investments_no_open_positions_yet => 'No open positions yet.';

  @override
  String get investments_old_positions_label => 'Past positions';

  @override
  String investments_delete_leveraged_position_confirm_title(String market) {
    return 'Delete \"$market\"?';
  }

  @override
  String get investments_delete_leveraged_position_confirm_message =>
      'This position will be permanently deleted. This action is irreversible.';

  @override
  String get investments_leveraged_section_title => 'Leveraged positions';

  @override
  String get investments_add_position_link => 'Add a position';

  @override
  String get investments_no_leveraged_positions_yet =>
      'No leveraged positions yet.';

  @override
  String get investments_closed_positions_label => 'Closed positions';

  @override
  String get investments_column_entry_label => 'Entry';

  @override
  String get investments_column_price_label => 'Price';

  @override
  String get investments_column_amount_label => 'Amount';

  @override
  String get investments_pnl_roe_column_label => 'PnL (ROE)';

  @override
  String get investments_refresh_menu_item => 'Refresh';

  @override
  String get investments_close_position_menu_item => 'Close';

  @override
  String get investments_position_closed_badge => 'Closed';

  @override
  String investments_liquidation_price_label(String price) {
    return 'Liquidation: $price';
  }

  @override
  String investments_delete_investment_confirm_title(String label) {
    return 'Delete \"$label\"?';
  }

  @override
  String get investments_delete_investment_confirm_message =>
      'This investment will be permanently deleted.';

  @override
  String get investments_transfer_to_account_menu_item =>
      'Transfer to another account';

  @override
  String get investments_arbitrage_to_security_menu_item =>
      'Switch to another security';

  @override
  String get investments_merge_with_position_menu_item =>
      'Merge with another position';

  @override
  String get investments_delete_investment_requires_empty_tooltip =>
      'Delete its transactions first';

  @override
  String get investments_delete_investment_menu_item => 'Delete the investment';

  @override
  String get investments_receipt_save_dialog_title => 'Save the receipt';

  @override
  String investments_receipt_document_name(String month) {
    return 'Receipt $month';
  }

  @override
  String get investments_receipt_saved_toast_title => 'Receipt saved';

  @override
  String get investments_receipt_save_failed_toast_title => 'Save failed';

  @override
  String investments_receipt_save_failed_subtitle(String error) {
    return 'The receipt could not be generated or saved: $error';
  }

  @override
  String get investments_isin_copied_toast_title => 'ISIN copied';

  @override
  String get investments_quantity_held_label => 'Quantity held';

  @override
  String get investments_last_price_label => 'Last price';

  @override
  String investments_performance_annualized_label(String rate) {
    return '$rate / year';
  }

  @override
  String investments_performance_since_start_label(String rate) {
    return '$rate since inception';
  }

  @override
  String get investments_not_enough_price_history =>
      'Not enough price history for this calculation.';

  @override
  String get investments_twr_explanation =>
      'TWR (Time-Weighted Return): the asset\'s performance, independent of when your contributions were made.';

  @override
  String get investments_mwr_explanation =>
      'MWR (Money-Weighted Return): the return actually earned, taking into account the amount and date of each contribution.';

  @override
  String investments_price_not_found_hint(String isin) {
    return 'No price found on Yahoo Finance for \"$isin\": unknown identifier or unlisted asset. Check the identifier — the value above is the net amount invested (purchase price), not the current market price.';
  }

  @override
  String get investments_price_not_yet_available_hint =>
      'Real-time price not yet available: the value above is the net amount invested (purchase price), not the current market price.';

  @override
  String get investments_tab_profitability => 'Profitability';

  @override
  String get investments_ibkr_import_dialog_title => 'Import IBKR statement';

  @override
  String investments_ibkr_period_label(String start, String end) {
    return 'Period: $start → $end';
  }

  @override
  String get investments_ibkr_row_security_trades =>
      'Security purchases / sales';

  @override
  String get investments_ibkr_row_currency_conversions =>
      'Currency conversions';

  @override
  String get investments_ibkr_row_dividends => 'Dividends';

  @override
  String get investments_ibkr_row_withholding_tax => 'Withholding tax';

  @override
  String get investments_ibkr_row_fees => 'Fees';

  @override
  String get investments_ibkr_row_deposits => 'Deposits';

  @override
  String get investments_ibkr_row_withdrawals => 'Withdrawals';

  @override
  String get investments_ibkr_row_other_flows => 'Other movements';

  @override
  String get investments_ibkr_empty_state =>
      'No new transactions to import — this file has already been imported, or contains no recognized lines.';

  @override
  String investments_ibkr_duplicates_skipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines already imported — skipped.',
      one: '1 line already imported — skipped.',
    );
    return '$_temp0';
  }

  @override
  String get investments_ibkr_warnings_title => 'Warnings';

  @override
  String get investments_ibkr_import_button => 'Import';

  @override
  String investments_transfer_title(String label) {
    return 'Transfer \"$label\"';
  }

  @override
  String investments_arbitrage_title(String label) {
    return 'Arbitrage \"$label\"';
  }

  @override
  String get investments_transfer_description =>
      'The average cost is kept: the sale here and the purchase on the destination account both use the current average cost — no capital gain is realized by the transfer itself.';

  @override
  String get investments_arbitrage_description =>
      'The sale happens at market price (realizing the unrealized gain/loss); the proceeds exactly fund the purchase of the new holding.';

  @override
  String get investments_field_pru_kept => 'Avg. cost kept';

  @override
  String get investments_no_other_account_for_transfer =>
      'No other account available for a transfer.';

  @override
  String get investments_field_dest_account => 'To account';

  @override
  String get investments_field_dest_buy_price => 'Destination buy price';

  @override
  String get investments_amount_obtained_placeholder => 'Amount obtained: —';

  @override
  String investments_amount_obtained_value(String amount) {
    return 'Amount obtained: $amount';
  }

  @override
  String investments_amount_obtained_with_bought_quantity(
    String amount,
    String quantity,
  ) {
    return 'Amount obtained: $amount → quantity bought: $quantity';
  }

  @override
  String get investments_transfer_button => 'Transfer';

  @override
  String get investments_arbitrage_button => 'Arbitrage';

  @override
  String get investments_transfer_impossible_title => 'Transfer not possible';

  @override
  String get investments_arbitrage_impossible_title => 'Arbitrage not possible';

  @override
  String get investments_error_dest_account_required =>
      'Choose a destination account.';

  @override
  String get investments_error_new_position_fields_required =>
      'Fill in the label (and the identifier if required) of the new position.';

  @override
  String get investments_error_pru_must_be_positive =>
      'Avg. cost must be a number greater than 0.';
}
