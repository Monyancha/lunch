import { connect } from 'react-redux';
import { showModal } from '../actions/modals';
import { showMapAndInfoWindow } from '../actions/mapUi';
import { showEditNameForm, setEditNameFormValue } from '../actions/listUi';
import RestaurantDropdown from '../components/RestaurantDropdown';

const mapStateToProps = (state, ownProps) => ({
  restaurant: state.restaurants.items.find(restaurant => restaurant.id === ownProps.id),
  listUiItem: state.listUi[ownProps.id] || {},
  ...ownProps
});

const mapDispatchToProps = (dispatch, ownProps) => ({
  showMapAndInfoWindow() {
    dispatch(showMapAndInfoWindow(ownProps.id));
  },
  deleteRestaurant: () => {
    dispatch(showModal('deleteRestaurant', { restaurantId: ownProps.id }));
  },
  dispatch
});

const mergeProps = (stateProps, dispatchProps, ownProps) => Object.assign({}, stateProps, dispatchProps, {
  showEditNameForm() {
    dispatchProps.dispatch(setEditNameFormValue(ownProps.id, stateProps.restaurant.name));
    dispatchProps.dispatch(showEditNameForm(ownProps.id));
  }
});

export default connect(
  mapStateToProps,
  mapDispatchToProps,
  mergeProps
)(RestaurantDropdown);