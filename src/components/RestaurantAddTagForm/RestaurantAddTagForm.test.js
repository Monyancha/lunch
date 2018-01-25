/* eslint-env mocha */
/* eslint-disable padded-blocks, no-unused-expressions */

import React from 'react';
import sinon from 'sinon';
import { expect } from 'chai';
import { shallow } from 'enzyme';
import { _RestaurantAddTagForm as RestaurantAddTagForm } from './RestaurantAddTagForm';

describe('RestaurantAddTagForm', () => {
  let props;

  beforeEach(() => {
    props = {
      addNewTagToRestaurant: sinon.mock(),
      handleSuggestionSelected: sinon.mock(),
      autosuggestValue: '',
      tags: []
    };
  });

  it('disables add button when autosuggest value is blank', () => {
    const wrapper = shallow(<RestaurantAddTagForm {...props} />, {disableLifecycleMethods: true});
    expect(wrapper.render().find('button').first()
      .attr('disabled')).to.eq('disabled');
  });
});
