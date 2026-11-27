import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_selector/file_selector.dart';

import '../../../core/widgets/page_header.dart';
import '../../../core/constants/build_info.dart';
import '../../printing/presentation/printing_settings_card.dart';
import '../../backups/presentation/backup_settings_card.dart';
import 'settings_controller.dart';

class SettingsScreen extends GetView<SettingsController> {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.errorMessage.value case final error?) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Unable to load settings: $error'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: controller.load,
                child: const Text('Try again'),
              ),
            ],
          ),
        );
      }
      return Form(
        key: controller.formKey,
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            PageHeader(
              title: 'Settings',
              subtitle: 'Company details used throughout the application.',
              action: Obx(
                () => ElevatedButton.icon(
                  onPressed: controller.isSaving.value ? null : controller.save,
                  icon: controller.isSaving.value
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('Save changes'),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Business identity',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),
                    _twoColumns(
                      _field(
                        controller.companyName,
                        'Company name',
                        required: true,
                      ),
                      _field(
                        controller.ownerName,
                        'Owner name',
                        required: true,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _twoColumns(
                      _field(
                        controller.primaryPhone,
                        'Primary phone',
                        required: true,
                      ),
                      _field(controller.secondaryPhone, 'Secondary phone'),
                    ),
                    const SizedBox(height: 18),
                    _twoColumns(
                      _field(controller.contactName, 'Additional contact name'),
                      _field(
                        controller.contactPhone,
                        'Additional contact phone',
                      ),
                    ),
                    const SizedBox(height: 18),
                    _field(
                      controller.email,
                      'Email address',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isNotEmpty && !GetUtils.isEmail(text)) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    _field(
                      controller.address,
                      'Business address',
                      required: true,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final path = Obx(
                          () => Text(
                            controller.logoPath.value == null
                                ? 'Using built-in Euro Tech logo'
                                : controller.logoPath.value!.isEmpty
                                ? 'Logo disabled'
                                : controller.logoPath.value!,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                        final choose = OutlinedButton.icon(
                          onPressed: () async {
                            final file = await openFile(
                              acceptedTypeGroups: const [
                                XTypeGroup(
                                  label: 'Logo image',
                                  extensions: ['png', 'jpg', 'jpeg'],
                                ),
                              ],
                            );
                            if (file != null) {
                              controller.logoPath.value = file.path;
                            }
                          },
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Choose logo'),
                        );
                        final remove =
                            controller.logoPath.value?.isNotEmpty ?? false
                            ? IconButton(
                                tooltip: 'Disable logo',
                                onPressed: () => controller.logoPath.value = '',
                                icon: const Icon(Icons.close_rounded),
                              )
                            : null;
                        if (constraints.maxWidth < 600) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              path,
                              const SizedBox(height: 10),
                              Wrap(spacing: 8, children: [choose, ?remove]),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: path),
                            const SizedBox(width: 12),
                            choose,
                            ?remove,
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const PrintingSettingsCard(),
            const SizedBox(height: 18),
            const BackupSettingsCard(),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'EURO TECH',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Text('EDGING AND CUTTING'),
                    const SizedBox(height: 8),
                    Text(
                      'Euro Tech Billing ${BuildInfo.display} • Offline desktop edition',
                      style: TextStyle(color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Historical payments are immutable. Corrections require an audited compensating-entry workflow, which is not included in this release.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _twoColumns(Widget first, Widget second) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 650) {
        return Column(children: [first, const SizedBox(height: 18), second]);
      }
      return Row(
        children: [
          Expanded(child: first),
          const SizedBox(width: 18),
          Expanded(child: second),
        ],
      );
    },
  );

  Widget _field(
    TextEditingController textController,
    String label, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: textController,
    maxLines: maxLines,
    keyboardType: keyboardType,
    decoration: InputDecoration(labelText: label),
    validator:
        validator ??
        (value) => required && (value?.trim().isEmpty ?? true)
            ? '$label is required'
            : null,
  );
}
