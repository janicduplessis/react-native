/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @flow strict-local
 * @format
 */

'use strict';

import type {RNTesterModuleExample} from '../../types/RNTesterTypes';
import type {SafeAreaInsetsChangeEvent} from 'react-native/Libraries/Types/CoreEventTypes';

import RNTesterText from '../../components/RNTesterText';
import * as React from 'react';
import {useCallback, useState} from 'react';
import {
  Button,
  Modal,
  StyleSheet,
  View,
  useWindowDimensions,
} from 'react-native';

type Insets = SafeAreaInsetsChangeEvent['nativeEvent']['insets'];
type Frame = SafeAreaInsetsChangeEvent['nativeEvent']['frame'];

function useSafeAreaInsets(): [
  ?Insets,
  ?Frame,
  (SafeAreaInsetsChangeEvent) => void,
] {
  const [state, setState] = useState<?{insets: Insets, frame: Frame}>(null);
  const onSafeAreaInsetsChange = useCallback(
    (event: SafeAreaInsetsChangeEvent) => {
      setState({
        insets: event.nativeEvent.insets,
        frame: event.nativeEvent.frame,
      });
    },
    [],
  );
  return [state?.insets, state?.frame, onSafeAreaInsetsChange];
}

function InsetsReadoutExample(): React.Node {
  const [insets, frame, onSafeAreaInsetsChange] = useSafeAreaInsets();

  return (
    <View
      onSafeAreaInsetsChange={onSafeAreaInsetsChange}
      style={styles.readout}>
      <RNTesterText>
        {insets == null
          ? 'Waiting for insets…'
          : `insets: {top: ${insets.top}, right: ${insets.right}, bottom: ${insets.bottom}, left: ${insets.left}}`}
      </RNTesterText>
      <RNTesterText>
        {frame == null
          ? ''
          : `frame: {x: ${frame.x}, y: ${frame.y}, width: ${frame.width}, height: ${frame.height}}`}
      </RNTesterText>
      <RNTesterText>
        This view does not reach under the system UI, so its insets are zero.
      </RNTesterText>
    </View>
  );
}

function FullScreenExample(): React.Node {
  const [modalVisible, setModalVisible] = useState(false);
  const [insets, , onSafeAreaInsetsChange] = useSafeAreaInsets();

  return (
    <View>
      <Modal
        visible={modalVisible}
        onRequestClose={() => setModalVisible(false)}
        animationType="slide"
        supportedOrientations={['portrait', 'landscape']}>
        <View
          onSafeAreaInsetsChange={onSafeAreaInsetsChange}
          style={[
            styles.modal,
            insets == null
              ? null
              : {
                  paddingTop: insets.top,
                  paddingRight: insets.right,
                  paddingBottom: insets.bottom,
                  paddingLeft: insets.left,
                },
          ]}>
          <View style={styles.modalContent}>
            <RNTesterText>
              {insets == null
                ? 'Waiting for insets…'
                : `top: ${insets.top}, right: ${insets.right}, bottom: ${insets.bottom}, left: ${insets.left}`}
            </RNTesterText>
            <RNTesterText>
              Rotate the device: the padding follows the insets in the same
              frame as the rotation, without the content jumping.
            </RNTesterText>
            <Button onPress={() => setModalVisible(false)} title="Close" />
          </View>
        </View>
      </Modal>
      <Button
        onPress={() => setModalVisible(true)}
        title="Present a full screen modal"
      />
    </View>
  );
}

function WindowInsetsExample(): React.Node {
  const {width, height, safeAreaInsets} = useWindowDimensions();

  return (
    <View style={styles.readout}>
      <RNTesterText>{`window: {width: ${width}, height: ${height}}`}</RNTesterText>
      <RNTesterText>
        {safeAreaInsets == null
          ? 'safeAreaInsets: not available'
          : `safeAreaInsets: {top: ${safeAreaInsets.top}, right: ${safeAreaInsets.right}, bottom: ${safeAreaInsets.bottom}, left: ${safeAreaInsets.left}}`}
      </RNTesterText>
    </View>
  );
}

const styles = StyleSheet.create({
  readout: {
    backgroundColor: '#ffaaaa',
    padding: 8,
    rowGap: 4,
  },
  modal: {
    flex: 1,
    backgroundColor: '#ffaaaa',
  },
  modalContent: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    rowGap: 8,
    backgroundColor: 'white',
  },
});

exports.displayName = undefined as ?string;
exports.framework = 'React';
exports.title = 'Safe area insets';
exports.category = 'UI';
exports.description =
  'The `onSafeAreaInsetsChange` view prop reports the part of a view that is covered by the system UI.';
exports.examples = [
  {
    title: 'Reading the insets of a view',
    description:
      'The insets are relative to the view they are reported for: a view that is already laid out inside the safe area has no insets.',
    render: (): React.Node => <InsetsReadoutExample />,
  },
  {
    title: 'Applying the insets as padding',
    description:
      'A full screen view that pads itself by its own safe area insets.',
    render: (): React.Node => <FullScreenExample />,
  },
  {
    title: 'Window safe area insets from Dimensions',
    description:
      'The `Dimensions` module reports the safe area insets of the window, available synchronously at startup.',
    render: (): React.Node => <WindowInsetsExample />,
  },
] as Array<RNTesterModuleExample>;
