/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @flow strict-local
 * @format
 */

import type {HostInstance} from '../../../src/private/types/HostInstance';

import SafeAreaView_INTERNAL_DO_NOT_USE from '../../../src/private/components/safeareaview/SafeAreaView_INTERNAL_DO_NOT_USE';

export type SafeAreaViewInstance = HostInstance;

/**
 * Renders content within the safe area boundaries of a device, by applying the
 * part of the view that is covered by the system UI as padding.
 *
 * @see https://reactnative.dev/docs/safeareaview
 * @deprecated Use `react-native-safe-area-context` instead.
 */
const SafeAreaView: typeof SafeAreaView_INTERNAL_DO_NOT_USE =
  SafeAreaView_INTERNAL_DO_NOT_USE;

export default SafeAreaView;
