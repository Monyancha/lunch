/**
 * React Starter Kit (https://www.reactstarterkit.com/)
 *
 * Copyright © 2014-2016 Kriasoft, LLC. All rights reserved.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE.txt file in the root directory of this source tree.
 */

/* eslint-env mocha */
/* eslint-disable padded-blocks, no-unused-expressions */

import React from 'react';
import { expect } from 'chai';
import { shallow } from 'enzyme';
import sinon from 'sinon';
import Layout from './Layout';

const context = { insertCss: () => {} };

describe('App', () => {
  let props;

  beforeEach(() => {
    props = {
      wsPort: 3000,
      messageReceived: sinon.mock(),
      shouldScrollToTop: false,
      scrolledToTop: sinon.mock()
    };
  });

  it('renders children correctly', () => {
    const wrapper = shallow(
      <Layout {...props}>
        <div className="child" />
      </Layout>,
    { context });

    expect(wrapper.contains(<div className="child" />)).to.be.true;
  });

});
