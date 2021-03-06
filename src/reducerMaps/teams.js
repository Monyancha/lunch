import update from 'immutability-helper';
import ActionTypes from '../constants/ActionTypes';
import isFetching from './helpers/isFetching';

export default new Map([
  [ActionTypes.POST_TEAM, isFetching],
  [ActionTypes.TEAM_POSTED, (state, action) => update(state, {
    isFetching: {
      $set: false
    },
    items: {
      result: {
        $push: [action.team.id]
      },
      entities: {
        teams: state.items.entities.teams ? {
          $merge: {
            [action.team.id]: action.team
          }
        } : {
          $set: {
            [action.team.id]: action.team
          }
        }
      }
    }
  })],
  [ActionTypes.USER_DELETED, (state, action) => {
    if (action.isSelf) {
      return update(state, {
        items: {
          result: {
            $splice: [[state.items.result.indexOf(action.team.id), 1]]
          }
        }
      });
    }
    return state;
  }],
]);
