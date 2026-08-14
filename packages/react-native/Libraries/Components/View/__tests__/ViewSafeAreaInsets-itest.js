/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @flow strict-local
 * @format
 */

import '@react-native/fantom/src/setUpDefaultReactNativeEnvironment';

import type {HostInstance} from 'react-native/src/private/types/HostInstance';

import * as Fantom from '@react-native/fantom';
import * as React from 'react';
import {createRef} from 'react';
import {View} from 'react-native';
import SafeAreaView from 'react-native/src/private/components/safeareaview/SafeAreaView_INTERNAL_DO_NOT_USE';

const INSETS = {top: 44, right: 0, bottom: 34, left: 0};
const FRAME = {x: 0, y: 0, width: 390, height: 844};

describe('onSafeAreaInsetsChange', () => {
  it('delivers the insets and the frame of the view', () => {
    const root = Fantom.createRoot();
    const nodeRef = createRef<HostInstance>();
    const onSafeAreaInsetsChange = jest.fn();

    Fantom.runTask(() => {
      root.render(
        <View
          collapsable={false}
          ref={nodeRef}
          onSafeAreaInsetsChange={event => {
            onSafeAreaInsetsChange(event.nativeEvent);
          }}
        />,
      );
    });

    Fantom.dispatchNativeEvent(nodeRef, 'safeAreaInsetsChange', {
      insets: INSETS,
      frame: FRAME,
    });

    expect(onSafeAreaInsetsChange).toHaveBeenCalledTimes(1);
    const [event] = onSafeAreaInsetsChange.mock.lastCall;
    expect(event.insets).toEqual(INSETS);
    expect(event.frame).toEqual(FRAME);
  });

  it('is not delivered to views that did not opt in', () => {
    const root = Fantom.createRoot();
    const nodeRef = createRef<HostInstance>();

    Fantom.runTask(() => {
      root.render(<View collapsable={false} ref={nodeRef} />);
    });

    // The prop is what makes the view observe the safe area, so a view without
    // it is never the target of the event.
    expect(
      root.getRenderedOutput({props: ['onSafeAreaInsetsChange']}).toJSX(),
    ).toEqual(<rn-view />);
  });

  it('is reflected in the props of the view when set', () => {
    const root = Fantom.createRoot();

    Fantom.runTask(() => {
      root.render(
        <View collapsable={false} onSafeAreaInsetsChange={() => {}} />,
      );
    });

    expect(
      root.getRenderedOutput({props: ['onSafeAreaInsetsChange']}).toJSX(),
    ).toEqual(<rn-view onSafeAreaInsetsChange="true" />);
  });
});

describe('<SafeAreaView>', () => {
  it('applies the insets it receives as padding', () => {
    const root = Fantom.createRoot();
    const nodeRef = createRef<HostInstance>();

    Fantom.runTask(() => {
      root.render(<SafeAreaView collapsable={false} ref={nodeRef} />);
    });

    expect(
      root
        .getRenderedOutput({
          props: ['paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft'],
        })
        .toJSX(),
    ).toEqual(<rn-view />);

    Fantom.dispatchNativeEvent(nodeRef, 'safeAreaInsetsChange', {
      insets: INSETS,
      frame: FRAME,
    });

    expect(
      root
        .getRenderedOutput({
          props: ['paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft'],
        })
        .toJSX(),
    ).toEqual(
      <rn-view
        paddingBottom="34"
        paddingLeft="0"
        paddingRight="0"
        paddingTop="44"
      />,
    );
  });
});
