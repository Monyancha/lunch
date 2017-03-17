/* eslint-env mocha */
/* eslint-disable padded-blocks, no-unused-expressions */

import React from 'react';
import sinon from 'sinon';
import { expect } from 'chai';
import { shallow } from 'enzyme';
import { undecorated as Restaurant } from './Restaurant';
import RestaurantAddTagFormContainer from '../RestaurantAddTagForm/RestaurantAddTagFormContainer';

describe('Restaurant', () => {
  let props;

  beforeEach(() => {
    props = {
      restaurant: {
        tags: []
      },
      shouldShowAddTagArea: true,
      shouldShowDropdown: true,
      loggedIn: true,
      listUiItem: {},
      showAddTagForm: sinon.mock(),
      showMapAndInfoWindow: sinon.mock(),
      removeTag: sinon.mock(),
      teamSlug: 'foo',
    };
  });

  it('renders add tag form when user is adding tags', () => {
    const wrapper = shallow(<Restaurant {...props} />);
    expect(wrapper.find(RestaurantAddTagFormContainer).length).to.eq(0);
    wrapper.setProps({ listUiItem: { isAddingTags: true } });
    expect(wrapper.find(RestaurantAddTagFormContainer).length).to.eq(1);
  });
});
