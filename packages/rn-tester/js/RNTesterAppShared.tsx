import React, {useState} from 'react';
import {Button, StyleSheet, View} from 'react-native';

const N = 20;

export default function Reproducer() {
  const [rotation, setRotation] = useState(0);

  return (
    <View style={styles.container}>
      <Button
        title="Set rotation"
        onPress={() => setRotation(Math.random() * 2 * Math.PI)}
      />
      {[...new Array(N)].map((_, i) => (
        <View key={i} style={styles.row}>
          {[...new Array(N)].map((__, j) => (
            <View
              key={j}
              style={[styles.box, {transform: [{rotate: `${rotation}rad`}]}]}
            />
          ))}
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'center',
  },
  box: {
    backgroundColor: 'navy',
    width: 400 / N,
    height: 400 / N,
    marginRight: 1,
    marginBottom: 1,
  },
});
