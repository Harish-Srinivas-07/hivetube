import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/update/update_controller.dart';
import '../../core/update/update_service.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/ui.dart';
import '../watch/mini_player_inset.dart';

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  late final Future<PackageInfo> _packageInfo;

  @override
  void initState() {
    super.initState();
    _packageInfo = PackageInfo.fromPlatform();
    Future.microtask(() {
      if (!mounted) return;
      final state = ref.read(updateControllerProvider);
      if (state is UpdateIdle ||
          state is UpdateUpToDate ||
          state is UpdateFailed) {
        unawaited(ref.read(updateControllerProvider.notifier).check());
      }
    });
  }

  Future<void> _openLink(String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      AppSnackbar.showError(context, 'Could not open link');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final update = ref.watch(updateControllerProvider);
    final repo = githubLatestReleasePage.substring(
      0,
      githubLatestReleasePage.length - '/releases/latest'.length,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: FutureBuilder<PackageInfo>(
        future: _packageInfo,
        builder: (context, snapshot) {
          final info = snapshot.data;
          final name = info?.appName.trim();
          final signature = info?.buildSignature.trim();
          final installer = info?.installerStore?.trim();
          final version = info == null
              ? 'N/A'
              : '${info.version} (${info.buildNumber})';
          return ListView(
            padding: EdgeInsets.only(
              bottom:
                  MediaQuery.paddingOf(context).bottom +
                  MiniPlayerInset.of(context) +
                  AppSpacing.lg,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/brand/logo.png',
                      width: AppSizes.avatarLg,
                      height: AppSizes.avatarLg,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      name == null || name.isEmpty ? 'HiveTube' : name,
                      style: AppTextStyles.pageTitle,
                    ),
                    Text(
                      version,
                      style: AppTextStyles.meta.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SectionHeader(title: 'App information'),
              AppListTile(title: 'Version', subtitle: version),
              AppListTile(
                title: 'Package ID',
                subtitle: info?.packageName ?? 'N/A',
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                title: const Text(
                  'Build signature',
                  style: AppTextStyles.settingsTitle,
                ),
                subtitle: Text(
                  signature == null || signature.isEmpty ? 'N/A' : signature,
                  style: AppTextStyles.settingsSub,
                ),
              ),
              AppListTile(
                title: 'Installer store',
                subtitle: installer == null || installer.isEmpty
                    ? 'Unknown'
                    : installer,
              ),
              if (update case UpdateAvailable(:final info)) ...[
                const SectionHeader(title: 'Update'),
                AppListTile(
                  leading: const Icon(LucideIcons.download),
                  title: 'Update available',
                  subtitle: 'Version ${info.version}',
                  trailing: const Icon(LucideIcons.externalLink),
                  onTap: () => _openLink(info.releaseUrl.toString()),
                ),
              ],
              const SectionHeader(title: 'Project'),
              _link('HiveTube repository', repo, LucideIcons.codeXml),
              _link(
                'Latest release',
                githubLatestReleasePage,
                LucideIcons.download,
              ),
              const SectionHeader(title: 'Credits'),
              _link(
                'TheHiveMinds',
                'https://thehiveminds.in/',
                LucideIcons.globe,
              ),
              _link('Contact', 'mailto:info@thehiveminds.in', LucideIcons.mail),
              _link(
                'GitHub',
                'https://github.com/Harish-Srinivas-07',
                LucideIcons.codeXml,
              ),
              _link(
                'LinkedIn',
                'https://www.linkedin.com/in/harishsrinivas-sr/',
                LucideIcons.briefcaseBusiness,
              ),
              _link(
                'Portfolio',
                'https://harishsrinivas.netlify.app/',
                LucideIcons.userRound,
              ),
              _link(
                'Instagram',
                'https://www.instagram.com/being_exception',
                LucideIcons.camera,
              ),
              _link(
                'Medium',
                'https://medium.com/@sr.harishsrinivas',
                LucideIcons.bookOpenText,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'Thanks to InnerTube, YouPipe, and the Flow app for references.',
                  style: AppTextStyles.body.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SectionHeader(title: 'Disclaimer & Legal Notice'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text:
                                'Hivefy is an independent music player. It is ',
                          ),
                          TextSpan(
                            text:
                                'not affiliated with, endorsed by, or connected to YouTube or Google',
                            style: AppTextStyles.bodyStrong.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                      style: AppTextStyles.body.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _noticeLine(
                      'Media and downloads:',
                      'Hivefy does not host or upload music. It accesses third-party services and stores user-requested downloads on the device for offline playback.',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _noticeLine(
                      'Third-party services:',
                      'Availability, content, and service behavior may change. Hivefy cannot guarantee uninterrupted access.',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _noticeLine(
                      'User responsibility:',
                      'Users are responsible for following applicable laws and the terms of services they use.',
                    ),
                  ],
                ),
              ),
              const SectionHeader(title: 'Need custom software?'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'Need software built? Contact us. We build applications, web apps, and more.',
                  style: AppTextStyles.body.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              _link(
                'Contact us',
                'https://thehiveminds.in/',
                LucideIcons.globe,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _link(String title, String url, IconData icon) => AppListTile(
    leading: Icon(icon),
    title: title,
    trailing: const Icon(LucideIcons.externalLink),
    onTap: () => _openLink(url),
  );

  Widget _noticeLine(String heading, String text) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: '• '),
          TextSpan(
            text: heading,
            style: AppTextStyles.bodyStrong.copyWith(color: color),
          ),
          TextSpan(text: ' $text'),
        ],
      ),
      style: AppTextStyles.body.copyWith(color: color),
    );
  }
}
