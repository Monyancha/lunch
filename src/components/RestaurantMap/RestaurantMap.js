import React, { Component, PropTypes } from 'react';
import { Provider } from 'react-redux';
import ContextHolder from '../../core/ContextHolder';
import RestaurantContainer from '../../containers/RestaurantContainer';
import { GoogleMapLoader, GoogleMap, Marker, InfoWindow } from 'react-google-maps';
import withStyles from 'isomorphic-style-loader/lib/withStyles';
import s from './RestaurantMap.scss';

class RestaurantMap extends Component {
  static contextTypes = {
    insertCss: PropTypes.func,
    store: PropTypes.object
  }

  renderInfoWindow(ref, item) {
    const boundHandleMarkerClose = this.props.handleMarkerClose.bind(this, item.id);

    return (
      <InfoWindow
        key={`${ref}_info_window`}
        onCloseclick={boundHandleMarkerClose}
      >
        <ContextHolder context={this.context}>
          <Provider store={this.context.store}>
            <div>
              <RestaurantContainer {...item} />
            </div>
          </Provider>
        </ContextHolder>
      </InfoWindow>
    );
  }

  render() {
    return (
      <section className={s.root}>
        <GoogleMapLoader
          containerElement={
            <div
              style={{
                height: '100%'
              }}
            />
          }
          googleMapElement={
            <GoogleMap
              defaultZoom={16}
              defaultCenter={this.props.latLng}
            >
              {this.props.items.map((item, index) => {
                const length = item.votes.length;
                let label = ' ';
                if (item.votes.length > 9) {
                  label = '✔';
                } else if (item.votes.length > 0) {
                  label = String(length);
                }

                const ref = `marker_${index}`;

                const boundHandleMarkerClick = this.props.handleMarkerClick.bind(this, item.id);

                return (
                  <Marker
                    position={{ lat: item.lat, lng: item.lng }}
                    label={label}
                    key={index}
                    title={item.name}
                    onClick={boundHandleMarkerClick}
                  >
                    {item.showInfoWindow ? this.renderInfoWindow(ref, item) : null}
                  </Marker>
                );
              })}
            </GoogleMap>
          }
        />
      </section>
    );
  }
}

RestaurantMap.propTypes = {
  handleMarkerClick: PropTypes.func.isRequired,
  handleMarkerClose: PropTypes.func.isRequired,
  items: PropTypes.array.isRequired,
  latLng: PropTypes.object.isRequired
};

export default withStyles(RestaurantMap, s);
