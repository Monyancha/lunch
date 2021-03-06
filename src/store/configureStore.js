import { combineReducers, createStore, applyMiddleware } from 'redux';
import { normalize } from 'normalizr';
import thunk from 'redux-thunk';
import { composeWithDevTools } from 'redux-devtools-extension/developmentOnly';
import { name, version } from '../../package.json';
import * as schemas from '../schemas';
import * as reducerMaps from '../reducerMaps';
import createHelpers from './createHelpers';
import createLogger from './logger';

const generateReducer = (map, initial) => (state = initial, action) => {
  const reducer = map.get(action.type);
  if (reducer === undefined) {
    return state;
  }

  return reducer(state, action);
};

const generateReducers = (newReducerMaps, normalizedInitialState) => {
  const reducers = {};

  Object.keys(newReducerMaps).forEach(mapName => {
    reducers[mapName] = generateReducer(reducerMaps[mapName], normalizedInitialState[mapName] || {});
  });

  return reducers;
};

// Add the reducer to your store on the `routing` key
export default function configureStore(initialState, helpersConfig) {
  const normalizedInitialState = JSON.parse(JSON.stringify(initialState));

  normalizedInitialState.restaurants.items = normalize(initialState.restaurants.items, [schemas.restaurant]);
  normalizedInitialState.tags.items = normalize(initialState.tags.items, [schemas.tag]);
  normalizedInitialState.teams.items = normalize(initialState.teams.items, [schemas.team]);
  normalizedInitialState.users.items = normalize(initialState.users.items, [schemas.user]);
  normalizedInitialState.restaurants.items.entities.votes = normalizedInitialState.restaurants.items.entities.votes || {};

  const reducers = generateReducers(reducerMaps, normalizedInitialState);

  const helpers = createHelpers(helpersConfig);
  const middleware = [thunk.withExtraArgument(helpers)];

  let enhancer;

  if (__DEV__) {
    middleware.push(createLogger());

    // https://github.com/zalmoxisus/redux-devtools-extension#14-using-in-production
    const composeEnhancers = composeWithDevTools({
      // Options: https://github.com/zalmoxisus/redux-devtools-extension/blob/master/docs/API/Arguments.md#options
      name: `${name}@${version}`,
    });

    // https://redux.js.org/docs/api/applyMiddleware.html
    enhancer = composeEnhancers(applyMiddleware(...middleware));
  } else {
    enhancer = applyMiddleware(...middleware);
  }

  const store = createStore(
    combineReducers(reducers),
    normalizedInitialState,
    enhancer
  );

  // Hot reload reducers (requires Webpack or Browserify HMR to be enabled)
  if (__DEV__ && module.hot) {
    module.hot.accept('../reducerMaps', () => {
      // eslint-disable-next-line global-require
      const newReducerMaps = require('../reducerMaps');
      const newReducers = generateReducers(newReducerMaps, normalizedInitialState);
      return store.replaceReducer(combineReducers(newReducers));
    });
  }

  return store;
}
