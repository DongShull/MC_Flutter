import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mc_client.dart';
import '../../../core/designsystem/mc_chrome.dart';
import '../../../core/designsystem/mc_icons.dart';
import '../../../core/designsystem/theme.dart';
import '../../../core/l10n/mc_l10n.dart';
import '../widgets/settings_ui.dart';

// ── 语言设置页 ──────────────────────────────────────────────────────────────

/// 设置 → 语言设置（绑定 `mcLanguageProvider`）。
class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(mcLanguageProvider);
    final ctrl = ref.read(mcLanguageProvider.notifier);
    final l10n = McL10n.of(context);

    final options = <(McAppLanguage, String, String)>[
      (
        McAppLanguage.system,
        l10n.settingsLanguageSystem,
        l10n.settingsLanguageSystemSubtitle,
      ),
      (McAppLanguage.zhHans, '简体中文', 'Simplified Chinese'),
      (McAppLanguage.zhHant, '繁體中文', 'Traditional Chinese'),
      (McAppLanguage.en, 'English', 'English'),
      (McAppLanguage.de, 'Deutsch', 'German'),
    ];

    return SettingsScaffold(
      title: l10n.settingsLanguagePageTitle,
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 36),
        children: [
          McInsetGroup(
            header: l10n.settingsLanguageHeader,
            footer: l10n.settingsLanguageFooter,
            children: [
              for (final (lang, title, sub) in options)
                McInsetRow(
                  icon: McIcons.translate,
                  iconColor: current == lang
                      ? McTokens.accentStrong
                      : McTokens.textMuted,
                  title: title,
                  subtitle: sub,
                  trailing: current == lang
                      ? const Icon(
                          McIcons.checkCircleFill,
                          size: 19,
                          color: McTokens.ok,
                        )
                      : null,
                  onTap: () async {
                    await ctrl.setLanguage(lang);
                    final nextL10n = McL10n.current;
                    final label = lang == McAppLanguage.system
                        ? nextL10n.settingsLanguageSystem
                        : lang.nativeName;
                    McToast.success(nextL10n.languageSwitched(label));
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 关于 MovieClaw（App Store 合规：版本、隐私、LGPL/MIT 开源许可全文、TMDB 声明）──

class _OpenSourceComponent {
  const _OpenSourceComponent({
    required this.name,
    required this.license,
    required this.sourceUrl,
    required this.licenseText,
  });

  final String name;
  final String license;
  final String sourceUrl;
  final String licenseText;
}

const _lgpl21Notice = '''
GNU LESSER GENERAL PUBLIC LICENSE
Version 2.1, February 1999

Copyright (C) 1991, 1999 Free Software Foundation, Inc.
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA

This library is free software; you can redistribute it and/or modify it under
the terms of the GNU Lesser General Public License as published by the Free
Software Foundation; either version 2.1 of the License, or (at your option)
any later version.

This library is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
details.

MovieClaw dynamically links the unmodified FFmpeg / libmpv multimedia libraries
in compliance with LGPL-2.1. Complete corresponding source code and build
instructions are publicly available at the upstream project repository linked
above.
''';

const _mitTemplate = '''
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''';

const _bsd3Template = '''
BSD 3-Clause License

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its contributors
   may be used to endorse or promote products derived from this software
   without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED.
''';

const _bsd2Template = '''
BSD 2-Clause License

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES ARE DISCLAIMED.
''';

const _iscTemplate = '''
ISC License

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS.
''';

const _apache2Template = '''
Apache License, Version 2.0

Licensed under the Apache License, Version 2.0 (the "License"); you may not use
this file except in compliance with the License. You may obtain a copy of the
License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied. See the License for the
specific language governing permissions and limitations under the License.
''';

const _openSourceComponents = <_OpenSourceComponent>[
  _OpenSourceComponent(
    name: 'FFmpeg',
    license: 'LGPL-2.1-or-later',
    sourceUrl: 'https://ffmpeg.org/download.html',
    licenseText: 'Copyright (c) 2000-2026 the FFmpeg developers\n\n$_lgpl21Notice',
  ),
  _OpenSourceComponent(
    name: 'libmpv / media_kit',
    license: 'LGPL-2.1-or-later / MIT',
    sourceUrl: 'https://github.com/media-kit/media-kit',
    licenseText:
        'libmpv (LGPL-2.1+) & media_kit Flutter bindings (MIT)\n\n$_lgpl21Notice\n\n$_mitTemplate',
  ),
  _OpenSourceComponent(
    name: 'dav1d (AV1 Decoder)',
    license: 'BSD-2-Clause',
    sourceUrl: 'https://code.videolan.org/videolan/dav1d',
    licenseText: 'Copyright (c) 2018-2026 VideoLAN and dav1d authors\n\n$_bsd2Template',
  ),
  _OpenSourceComponent(
    name: 'libass (Subtitle Renderer)',
    license: 'ISC',
    sourceUrl: 'https://github.com/libass/libass',
    licenseText: 'Copyright (c) 2006-2026 libass contributors\n\n$_iscTemplate',
  ),
  _OpenSourceComponent(
    name: 'Flutter SDK',
    license: 'BSD-3-Clause',
    sourceUrl: 'https://github.com/flutter/flutter',
    licenseText: 'Copyright 2014 The Flutter Authors\n\n$_bsd3Template',
  ),
  _OpenSourceComponent(
    name: 'Riverpod (flutter_riverpod)',
    license: 'MIT',
    sourceUrl: 'https://github.com/rrousselGit/riverpod',
    licenseText: 'Copyright (c) 2020 Remi Rousselet\n\n$_mitTemplate',
  ),
  _OpenSourceComponent(
    name: 'Dio HTTP Client',
    license: 'MIT',
    sourceUrl: 'https://github.com/cfug/dio',
    licenseText: 'Copyright (c) 2018-2026 CFUG / Dio Contributors\n\n$_mitTemplate',
  ),
  _OpenSourceComponent(
    name: 'go_router',
    license: 'BSD-3-Clause',
    sourceUrl: 'https://github.com/flutter/packages/tree/main/packages/go_router',
    licenseText: 'Copyright 2013 The Flutter Authors\n\n$_bsd3Template',
  ),
  _OpenSourceComponent(
    name: 'cryptography (Ed25519 / AES-GCM)',
    license: 'Apache-2.0',
    sourceUrl: 'https://github.com/dint-dev/cryptography',
    licenseText: 'Copyright 2019-2026 dint-dev\n\n$_apache2Template',
  ),
  _OpenSourceComponent(
    name: 'cached_network_image & fl_chart',
    license: 'MIT',
    sourceUrl: 'https://pub.dev',
    licenseText: 'MIT Licensed Flutter Community Packages\n\n$_mitTemplate',
  ),
];

/// 设置 → 关于 MovieClaw（所有人可见，1:1 对齐 iOS `AboutView.swift`）。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _projectUrl = 'https://github.com/movieclaw/movieclaw';
  static const _privacyUrl =
      'https://github.com/movieclaw/movieclaw/blob/main/docs/privacy-policy.md';
  static const _tmdbUrl = 'https://www.themoviedb.org';

  void _openLicense(BuildContext context, _OpenSourceComponent comp) {
    showMcSheet<void>(
      context: context,
      maxWidth: 640,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(comp.name, style: McText.titleSm),
            const SizedBox(height: 4),
            Text(comp.license, style: McText.caption.muted),
            const SizedBox(height: 10),
            McInsetGroup(
              margin: EdgeInsets.zero,
              children: [
                McInsetRow(
                  icon: McIcons.links,
                  title: '查看源码仓库',
                  subtitle: comp.sourceUrl,
                  onTap: () => openExternalUrl(ctx, comp.sourceUrl),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: McTokens.surfaceInset,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: McTokens.line),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    comp.licenseText,
                    style: McText.micro.copyWith(
                      fontFamily: 'monospace',
                      height: 1.45,
                      color: McTokens.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: '关于 MovieClaw',
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 36),
        children: [
          Center(
            child: Column(
              children: [
                const McBrandMark(size: 56),
                const SizedBox(height: 10),
                const Text('MovieClaw', style: McText.titleLg),
                const SizedBox(height: 4),
                Text(
                  '版本 ${McClient.appVersion} (Flutter)',
                  style: McText.caption.muted,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          McInsetGroup(
            header: '应用信息与隐私',
            footer:
                'MovieClaw 仅与你自己部署的私有服务器通信，不在未经授权的情况下收集个人观影记录或设备隐私数据。',
            children: [
              const McInsetRow(
                icon: McIcons.information,
                title: '客户端版本',
                valueText: McClient.appVersion,
              ),
              McInsetRow(
                icon: McIcons.fileCode2,
                title: '项目主页 (GitHub)',
                subtitle: _projectUrl,
                onTap: () => openExternalUrl(context, _projectUrl),
              ),
              McInsetRow(
                icon: McIcons.shieldCheck,
                title: '隐私政策',
                subtitle: '查看完整隐私说明与数据使用原则',
                onTap: () => openExternalUrl(context, _privacyUrl),
              ),
            ],
          ),
          const SizedBox(height: 18),
          McInsetGroup(
            header: '开源组件与许可协议',
            footer: '本应用包含受 LGPL、MIT、BSD、ISC 与 Apache-2.0 协议保护的开源软件；点击任意条目可离线阅读许可全文与源码链接。',
            children: [
              for (final comp in _openSourceComponents)
                McInsetRow(
                  icon: McIcons.copyright,
                  title: comp.name,
                  subtitle: comp.license,
                  onTap: () => _openLicense(context, comp),
                ),
            ],
          ),
          const SizedBox(height: 18),
          McInsetGroup(
            header: '数据来源声明',
            footer:
                'This product uses the TMDB API but is not endorsed or certified by TMDB.\n本产品使用 TMDB API，但未经 TMDB 认可或认证。',
            children: [
              McInsetRow(
                icon: McIcons.movie2,
                title: 'The Movie Database (TMDB)',
                subtitle: '影视元数据、剧照与演职员信息来源',
                onTap: () => openExternalUrl(context, _tmdbUrl),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
