import React, { PropTypes } from 'react';
import DeleteRestaurantModalContainer from '../DeleteRestaurantModal/DeleteRestaurantModalContainer';
import DeleteTagModalContainer from '../DeleteTagModal/DeleteTagModalContainer';

const ModalSection = ({ modals }) => {
  const modalContainers = [];
  if (modals.deleteRestaurant !== undefined) {
    modalContainers.push(<DeleteRestaurantModalContainer key="modalContainer_deleteRestaurant" />);
  }
  if (modals.deleteTag !== undefined) {
    modalContainers.push(<DeleteTagModalContainer key="modalContainer_deleteTag" />);
  }

  return (
    <div>
      {modalContainers}
    </div>
  );
};

ModalSection.propTypes = {
  modals: PropTypes.object.isRequired
};

export default ModalSection;
