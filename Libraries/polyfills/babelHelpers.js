/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @providesModule babelHelpers
 * @polyfill
 * @nolint
 */

/* eslint-disable quotes, curly, no-proto, no-undef-init, dot-notation */

// Created by running:
// require('fs').writeFileSync('babelExternalHelpers.js', require('@babel/core').buildExternalHelpers('_extends classCallCheck createClass createRawReactElement defineProperty getPrototypeOf setPrototypeOf get inherits  interopRequireDefault interopRequireWildcard objectWithoutProperties objectSpread possibleConstructorReturn slicedToArray arrayWithHoles arrayWithoutHoles taggedTemplateLiteral toArray toConsumableArray wrapNativeSuper assertThisInitialized taggedTemplateLiteralLoose applyDecoratedDescriptor'.split(' ')))// then replacing the `global` reference in the last line to also use `this`.
//
// Actually, that's a lie, because babel omits _extends and
// createRawReactElement. the file is also cleaned up a bit.
// You may need to clear wrapNativeSuper while the bug hasn't been fixed yet.
// Do try to keep diffs to a minimum.

var babelHelpers = (global.babelHelpers = {});

babelHelpers.createRawReactElement = (function() {
  var REACT_ELEMENT_TYPE =
    (typeof Symbol === 'function' &&
      Symbol.for &&
      Symbol.for('react.element')) ||
    0xeac7;
  return function createRawReactElement(type, key, props) {
    return {
      $$typeof: REACT_ELEMENT_TYPE,
      type: type,
      key: key,
      ref: null,
      props: props,
      _owner: null,
    };
  };
})();

babelHelpers._extends = babelHelpers.extends =
  Object.assign ||
  function(target) {
    for (var i = 1; i < arguments.length; i++) {
      var source = arguments[i];

      for (var key in source) {
        if (Object.prototype.hasOwnProperty.call(source, key)) {
          target[key] = source[key];
        }
      }
    }

    return target;
  };

function _classCallCheck(instance, Constructor) {
  if (!(instance instanceof Constructor)) {
    throw new TypeError('Cannot call a class as a function');
  }
}

babelHelpers.classCallCheck = _classCallCheck;

function _defineProperties(target, props) {
  for (var i = 0; i < props.length; i++) {
    var descriptor = props[i];
    descriptor.enumerable = descriptor.enumerable || false;
    descriptor.configurable = true;
    if ('value' in descriptor) descriptor.writable = true;
    Object.defineProperty(target, descriptor.key, descriptor);
  }
}

function _createClass(Constructor, protoProps, staticProps) {
  if (protoProps) _defineProperties(Constructor.prototype, protoProps);
  if (staticProps) _defineProperties(Constructor, staticProps);
  return Constructor;
}

babelHelpers.createClass = _createClass;

function _defineProperty(obj, key, value) {
  if (key in obj) {
    Object.defineProperty(obj, key, {
      value: value,
      enumerable: true,
      configurable: true,
      writable: true,
    });
  } else {
    obj[key] = value;
  }

  return obj;
}

babelHelpers.defineProperty = _defineProperty;

babelHelpers.getPrototypeOf = function(o) {
  _getPrototypeOf =
    Object.getPrototypeOf ||
    function _getPrototypeOf(o) {
      return o.__proto__;
    };
  return _getPrototypeOf(o);
};

babelHelpers.setPrototypeOf = function(o, p) {
  _setPrototypeOf =
    Object.setPrototypeOf ||
    function _setPrototypeOf(o, p) {
      o.__proto__ = p;
      return o;
    };
  return _setPrototypeOf(o, p);
};

function _inherits(subClass, superClass) {
  if (typeof superClass !== 'function' && superClass !== null) {
    throw new TypeError('Super expression must either be null or a function');
  }

  babelHelpers.setPrototypeOf(
    subClass.prototype,
    superClass && superClass.prototype,
  );
  if (superClass) babelHelpers.setPrototypeOf(subClass, superClass);
}

babelHelpers.inherits = _inherits;

function _wrapNativeSuper(Class) {
  var _cache = typeof Map === 'function' ? new Map() : undefined;

  babelHelpers.wrapNativeSuper = _wrapNativeSuper = function _wrapNativeSuper(
    Class,
  ) {
    if (typeof Class !== 'function') {
      throw new TypeError('Super expression must either be null or a function');
    }

    if (typeof _cache !== 'undefined') {
      if (_cache.has(Class)) return _cache.get(Class);

      _cache.set(Class, Wrapper);
    }

    function Wrapper() {}

    Wrapper.prototype = Object.create(Class.prototype, {
      constructor: {
        value: Wrapper,
        enumerable: false,
        writable: true,
        configurable: true,
      },
    });
    return babelHelpers.setPrototypeOf(
      Wrapper,
      babelHelpers.setPrototypeOf(function Super() {
        return babelHelpers.construct(
          Class,
          arguments,
          babelHelpers.getPrototypeOf(this).constructor,
        );
      }, Class),
    );
  };

  return _wrapNativeSuper(Class);
}

babelHelpers.wrapNativeSuper = _wrapNativeSuper;

function _interopRequireDefault(obj) {
  return obj && obj.__esModule
    ? obj
    : {
        default: obj,
      };
}

babelHelpers.interopRequireDefault = _interopRequireDefault;

function _interopRequireWildcard(obj) {
  if (obj && obj.__esModule) {
    return obj;
  } else {
    var newObj = {};

    if (obj != null) {
      for (var key in obj) {
        if (Object.prototype.hasOwnProperty.call(obj, key)) {
          var desc =
            Object.defineProperty && Object.getOwnPropertyDescriptor
              ? Object.getOwnPropertyDescriptor(obj, key)
              : {};

          if (desc.get || desc.set) {
            Object.defineProperty(newObj, key, desc);
          } else {
            newObj[key] = obj[key];
          }
        }
      }
    }

    newObj.default = obj;
    return newObj;
  }
}

babelHelpers.interopRequireWildcard = _interopRequireWildcard;

function _objectWithoutProperties(source, excluded) {
  if (source == null) return {};
  var target = {};
  var sourceKeys = Object.keys(source);
  var key, i;

  for (i = 0; i < sourceKeys.length; i++) {
    key = sourceKeys[i];
    if (excluded.indexOf(key) >= 0) continue;
    target[key] = source[key];
  }

  if (Object.getOwnPropertySymbols) {
    var sourceSymbolKeys = Object.getOwnPropertySymbols(source);

    for (i = 0; i < sourceSymbolKeys.length; i++) {
      key = sourceSymbolKeys[i];
      if (excluded.indexOf(key) >= 0) continue;
      if (!Object.prototype.propertyIsEnumerable.call(source, key)) continue;
      target[key] = source[key];
    }
  }

  return target;
}

babelHelpers.objectWithoutProperties = _objectWithoutProperties;

function _assertThisInitialized(self) {
  if (self === void 0) {
    throw new ReferenceError(
      "this hasn't been initialised - super() hasn't been called",
    );
  }

  return self;
}

babelHelpers.assertThisInitialized = _assertThisInitialized;

babelHelpers.objectSpread = function(target) {
  for (var i = 1; i < arguments.length; i++) {
    var source = arguments[i] != null ? arguments[i] : {};
    var ownKeys = Object.keys(source);
    if (typeof Object.getOwnPropertySymbols === 'function') {
      ownKeys = ownKeys.concat(
        Object.getOwnPropertySymbols(source).filter(function(sym) {
          return Object.getOwnPropertyDescriptor(source, sym).enumerable;
        }),
      );
    }
    ownKeys.forEach(function(key) {
      babelHelpers.defineProperty(target, key, source[key]);
    });
  }
  return target;
};

function _possibleConstructorReturn(self, call) {
  if (call && (typeof call === 'object' || typeof call === 'function')) {
    return call;
  }

  return babelHelpers.assertThisInitialized(self);
}

babelHelpers.possibleConstructorReturn = _possibleConstructorReturn;

function _get(target, property, receiver) {
  if (typeof Reflect !== 'undefined' && Reflect.get) {
    babelHelpers.get = _get = Reflect.get;
  } else {
    babelHelpers.get = _get = function _get(target, property, receiver) {
      var base = babelHelpers.superPropBase(target, property);
      if (!base) return;
      var desc = Object.getOwnPropertyDescriptor(base, property);

      if (desc.get) {
        return desc.get.call(receiver);
      }

      return desc.value;
    };
  }

  return _get(target, property, receiver || target);
}

babelHelpers.get = _get;

function _taggedTemplateLiteral(strings, raw) {
  if (!raw) {
    raw = strings.slice(0);
  }

  return Object.freeze(
    Object.defineProperties(strings, {
      raw: {
        value: Object.freeze(raw),
      },
    }),
  );
}

babelHelpers.taggedTemplateLiteral = _taggedTemplateLiteral;

function _taggedTemplateLiteralLoose(strings, raw) {
  if (!raw) {
    raw = strings.slice(0);
  }

  strings.raw = raw;
  return strings;
}

babelHelpers.taggedTemplateLiteralLoose = _taggedTemplateLiteralLoose;

function _slicedToArray(arr, i) {
  return (
    babelHelpers.arrayWithHoles(arr) ||
    babelHelpers.iterableToArrayLimit(arr, i) ||
    babelHelpers.nonIterableRest()
  );
}

babelHelpers.slicedToArray = _slicedToArray;

function _toArray(arr) {
  return (
    babelHelpers.arrayWithHoles(arr) ||
    babelHelpers.iterableToArray(arr) ||
    babelHelpers.nonIterableRest()
  );
}

babelHelpers.toArray = _toArray;

function _toConsumableArray(arr) {
  return (
    babelHelpers.arrayWithoutHoles(arr) ||
    babelHelpers.iterableToArray(arr) ||
    babelHelpers.nonIterableSpread()
  );
}

babelHelpers.toConsumableArray = _toConsumableArray;

function _arrayWithoutHoles(arr) {
  if (Array.isArray(arr)) {
    for (var i = 0, arr2 = new Array(arr.length); i < arr.length; i++)
      arr2[i] = arr[i];

    return arr2;
  }
}

babelHelpers.arrayWithoutHoles = _arrayWithoutHoles;

function _arrayWithHoles(arr) {
  if (Array.isArray(arr)) return arr;
}

babelHelpers.arrayWithHoles = _arrayWithHoles;

function _applyDecoratedDescriptor(
  target,
  property,
  decorators,
  descriptor,
  context,
) {
  var desc = {};
  Object['ke' + 'ys'](descriptor).forEach(function(key) {
    desc[key] = descriptor[key];
  });
  desc.enumerable = !!desc.enumerable;
  desc.configurable = !!desc.configurable;

  if ('value' in desc || desc.initializer) {
    desc.writable = true;
  }

  desc = decorators
    .slice()
    .reverse()
    .reduce(function(desc, decorator) {
      return decorator(target, property, desc) || desc;
    }, desc);

  if (context && desc.initializer !== void 0) {
    desc.value = desc.initializer ? desc.initializer.call(context) : void 0;
    desc.initializer = undefined;
  }

  if (desc.initializer === void 0) {
    Object['define' + 'Property'](target, property, desc);
    desc = null;
  }

  return desc;
}

babelHelpers.applyDecoratedDescriptor = _applyDecoratedDescriptor;
