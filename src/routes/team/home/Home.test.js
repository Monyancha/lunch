/* eslint-env mocha */
/* eslint-disable padded-blocks, no-unused-expressions */

import React from 'react';
import Adapter from 'enzyme-adapter-react-16';
import sinon from 'sinon';
import { expect } from 'chai';
import { shallow, configure } from 'enzyme';
import { _Home as Home } from './Home';
import RestaurantAddFormContainer from '../../../components/RestaurantAddForm/RestaurantAddFormContainer';

configure({ adapter: new Adapter() });

describe('Home', () => {
  let props;

  beforeEach(() => {
    props = {
      fetchDecisionIfNeeded: sinon.mock(),
      fetchRestaurantsIfNeeded: sinon.mock(),
      fetchTagsIfNeeded: sinon.mock(),
      fetchUsersIfNeeded: sinon.mock(),
      invalidateDecision: sinon.mock(),
      invalidateRestaurants: sinon.mock(),
      invalidateTags: sinon.mock(),
      invalidateUsers: sinon.mock(),
      messageReceived: sinon.mock(),
      wsPort: 3000
    };
  });

  it('renders form if user is logged in', () => {
    props.user = {
      id: 1
    };

    const wrapper = shallow(<Home {...props} />);
    expect(wrapper.find(RestaurantAddFormContainer).length).to.eq(1);
  });
});