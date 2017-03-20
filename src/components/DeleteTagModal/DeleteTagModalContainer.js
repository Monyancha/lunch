import { connect } from 'react-redux';
import { getTagById } from '../../selectors/tags';
import { removeTag } from '../../actions/tags';
import { hideModal } from '../../actions/modals';
import DeleteTagModal from './DeleteTagModal';

const modalName = 'deleteTag';

const mapStateToProps = state => ({
  tag: getTagById(state, state.modals[modalName].tagId),
  teamSlug: state.modals[modalName].teamSlug,
  shown: !!state.modals[modalName].shown
});

const mapDispatchToProps = dispatch => ({
  hideModal: () => {
    dispatch(hideModal(modalName));
  },
  dispatch
});

const mergeProps = (stateProps, dispatchProps) => Object.assign(stateProps, dispatchProps, {
  tagName: stateProps.tag.name,
  deleteTag: event => {
    event.preventDefault();
    dispatchProps.dispatch(removeTag(stateProps.teamSlug, stateProps.tag.id));
  }
});

export default connect(
  mapStateToProps,
  mapDispatchToProps,
  mergeProps
)(DeleteTagModal);
