/* eslint-env mocha */
/* eslint-disable padded-blocks, no-unused-expressions */

import Modal from 'react-bootstrap/lib/Modal';
import React from 'react';
import sinon from 'sinon';
import { expect } from 'chai';
import { shallow } from 'enzyme';
import DeleteTagModal from './DeleteTagModal';

describe('DeleteTagModal', () => {
  let props;

  beforeEach(() => {
    props = {
      tagName: 'gross',
      shown: true,
      hideModal: sinon.mock(),
      deleteTag: sinon.mock()
    };
  });

  it('renders confirmation text', () => {
    const wrapper = shallow(
      <DeleteTagModal {...props} />
    );
    expect(wrapper.find(Modal.Body).render().text())
      .to.contain('Are you sure you want to delete the “gross” tag?');
  });
});
