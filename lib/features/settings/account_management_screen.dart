import 'package:shadcn_flutter/shadcn_flutter.dart' hide Text;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn show Text;
import '../../core/profiles/profile_controller.dart';
import '../../core/profiles/profile_models.dart';
import '../../core/ui/frosted_card.dart';

class AccountManagementScreen extends StatefulWidget {
  final ProfileController profileController;
  const AccountManagementScreen({super.key, required this.profileController});

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  String? _editingId;
  final _editNameController = TextEditingController();
  final _editRelationshipController = TextEditingController();

  bool _creating = false;
  final _newNameController = TextEditingController();
  final _newRelationshipController = TextEditingController();

  @override
  void dispose() {
    _editNameController.dispose();
    _editRelationshipController.dispose();
    _newNameController.dispose();
    _newRelationshipController.dispose();
    super.dispose();
  }

  void _startEdit(Profile profile) {
    _editNameController.text = profile.name;
    _editRelationshipController.text = profile.relationship;
    setState(() => _editingId = profile.id);
  }

  Future<void> _commitEdit(String id) async {
    final name = _editNameController.text.trim();
    if (name.isEmpty) return;
    await widget.profileController.renameProfile(
      id,
      name: name,
      relationship: _editRelationshipController.text.trim(),
    );
    setState(() => _editingId = null);
  }

  Future<void> _commitCreate() async {
    final name = _newNameController.text.trim();
    if (name.isEmpty) return;
    await widget.profileController.createProfile(
      name: name,
      relationship: _newRelationshipController.text.trim(),
    );
    _newNameController.clear();
    _newRelationshipController.clear();
    setState(() => _creating = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.profileController,
      builder: (context, _) {
        final profiles = widget.profileController.profiles;
        final activeId = widget.profileController.active?.id;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          // Toute la largeur disponible, comme les autres pages : plus de
          // ConstrainedBox(maxWidth) qui cantonnait la carte à une colonne
          // centrale étroite.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const shadcn.Text('Comptes').large().medium(),
              const SizedBox(height: 4),
              const shadcn.Text(
                "Sépare le patrimoine, les budgets et les notes de stratégie de chaque personne. "
                "Toutes les données (stratégie, budget, actifs/passifs) sont propres à chaque compte.",
              ).muted().small(),
              const SizedBox(height: 20),
              FrostedCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final profile in profiles) ...[
                        if (_editingId == profile.id)
                          _buildEditRow(profile)
                        else
                          _buildProfileRow(
                            profile,
                            isActive: profile.id == activeId,
                          ),
                        const Divider(),
                      ],
                      const SizedBox(height: 8),
                      if (_creating) _buildCreateForm() else _buildAddButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileRow(Profile profile, {required bool isActive}) {
    final theme = Theme.of(context);

    final identity = Row(
      children: [
        Avatar(size: 36, initials: profile.initials),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: shadcn.Text(
                      profile.name,
                      overflow: TextOverflow.ellipsis,
                    ).medium(),
                  ),
                  if (profile.isMaster) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const shadcn.Text('Principal').small(),
                    ),
                  ],
                  if (isActive) ...[
                    const SizedBox(width: 6),
                    Icon(
                      LucideIcons.check,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
              if (profile.relationship.isNotEmpty)
                shadcn.Text(profile.relationship).muted().small(),
            ],
          ),
        ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isActive)
          OutlineButton(
            onPressed: () => widget.profileController.switchTo(profile.id),
            child: const shadcn.Text('Basculer'),
          ),
        IconButton.ghost(
          icon: const Icon(LucideIcons.pencil, size: 16),
          onPressed: () => _startEdit(profile),
        ),
        if (!profile.isMaster)
          IconButton.ghost(
            icon: const Icon(LucideIcons.trash2, size: 16),
            onPressed: () => widget.profileController.deleteProfile(profile.id),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // En dessous de ce seuil, le nom + les 3 actions (Basculer, crayon,
          // poubelle) ne tiennent plus sur une seule ligne sans se chevaucher :
          // les actions passent sur leur propre ligne, alignées à droite.
          final narrow = constraints.maxWidth < 420;
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: identity),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _buildEditRow(Profile profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _editNameController,
              placeholder: const shadcn.Text('Nom'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _editRelationshipController,
              placeholder: const shadcn.Text('Lien de parenté'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.ghost(
            icon: const Icon(LucideIcons.check, size: 16),
            onPressed: () => _commitEdit(profile.id),
          ),
          IconButton.ghost(
            icon: const Icon(LucideIcons.x, size: 16),
            onPressed: () => setState(() => _editingId = null),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newNameController,
                placeholder: const shadcn.Text('Nom (ex: Camille)'),
                autofocus: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _newRelationshipController,
                placeholder: const shadcn.Text('Lien de parenté (ex: Épouse)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            PrimaryButton(
              onPressed: _commitCreate,
              child: const shadcn.Text('Créer le compte'),
            ),
            const SizedBox(width: 8),
            OutlineButton(
              onPressed: () => setState(() => _creating = false),
              child: const shadcn.Text('Annuler'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: () => setState(() => _creating = true),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.userPlus,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          shadcn.Text(
            'Ajouter un compte',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}
