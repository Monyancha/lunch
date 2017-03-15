import { connect } from 'react-redux';
import { messageReceived } from '../../actions/websockets';
import { scrolledToTop } from '../../actions/pageUi';
import Layout from './Layout';

const mapStateToProps = (state, ownProps) => ({
  wsPort: state.wsPort,
  shouldScrollToTop: state.pageUi.shouldScrollToTop || false,
  ...ownProps
});

const mapDispatchToProps = dispatch => ({
  messageReceived(event) {
    dispatch(messageReceived(event.data));
  },
  scrolledToTop() {
    dispatch(scrolledToTop());
  }
});

export default connect(
  mapStateToProps,
  mapDispatchToProps
)(Layout);
