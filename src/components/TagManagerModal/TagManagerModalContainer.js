import { connect } from 'react-redux';
import { hideModal } from '../../actions/modals';
import TagManagerModal from './TagManagerModal';

const modalName = 'tagManager';

const mapStateToProps = state => ({
  shown: !!state.modals[modalName].shown,
  teamSlug: state.modals[modalName].teamSlug
});

const mapDispatchToProps = dispatch => ({
  hideModal: () => {
    dispatch(hideModal(modalName));
  }
});

export default connect(
  mapStateToProps,
  mapDispatchToProps
)(TagManagerModal);
