/*
 * Copyright (C) 2020. by perol_notsf, All rights reserved
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */

import 'dart:io';

class Constants {
  static const appleAppName = 'PixAP';
  static const appleAppTagline = '果味的PixEz';
  static bool get hasAppleBranding => Platform.isIOS || Platform.isMacOS;
  static String get displayName => hasAppleBranding ? appleAppName : 'PixEz';

  static const String no_h = 'assets/images/h_long.jpg';
  static const repositoryPath = "Duke486/PixAP";
  static const latestReleaseUrl =
      "https://github.com/$repositoryPath/releases/latest";
  static const latestReleaseApi =
      "https://api.github.com/repos/$repositoryPath/releases/latest";
  static int type = 0;
  static String? code_verifier = null;

}
