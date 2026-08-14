/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @flow strict-local
 * @format
 */

import type {ViewProps} from '../../../../Libraries/Components/View/ViewPropTypes';
import type {
  SafeAreaInsets,
  SafeAreaInsetsChangeEvent,
} from '../../../../Libraries/Types/CoreEventTypes';
import type {HostInstance} from '../../types/HostInstance';

import View from '../../../../Libraries/Components/View/View';
import * as React from 'react';
import {useCallback, useMemo, useState} from 'react';

/**
 * Renders its children within the safe area of the device, by applying the part
 * of the view that is covered by the system UI as padding.
 *
 * This is the internal counterpart of `react-native-safe-area-context`, for the
 * few surfaces React Native renders itself (LogBox, the element inspector, ...)
 * which cannot take a dependency on it. Everything else should use the library.
 */
component SafeAreaView(
  ref?: React.RefSetter<HostInstance>,
  ...props: ViewProps
) {
  const {style, onSafeAreaInsetsChange, ...otherProps} = props;
  const [insets, setInsets] = useState<?SafeAreaInsets>(null);

  const handleSafeAreaInsetsChange = useCallback(
    (event: SafeAreaInsetsChangeEvent) => {
      setInsets(event.nativeEvent.insets);
      onSafeAreaInsetsChange?.(event);
    },
    [onSafeAreaInsetsChange],
  );

  const paddingStyle = useMemo(
    () =>
      insets == null
        ? null
        : {
            paddingTop: insets.top,
            paddingRight: insets.right,
            paddingBottom: insets.bottom,
            paddingLeft: insets.left,
          },
    [insets],
  );

  return (
    <View
      {...otherProps}
      ref={ref}
      onSafeAreaInsetsChange={handleSafeAreaInsetsChange}
      style={[style, paddingStyle]}
    />
  );
}

export default SafeAreaView;
