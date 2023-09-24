import React, { Component } from 'react';
import { NavLink } from 'react-router-dom';

import logo from '../../assets/images/logo.svg';

export default class Footer extends Component {
    render() {
        return (
            <div className="footer">
                <div className="footer__body container">
                    <div className="footer-left">
                        <div className="logo">
                            <NavLink to="/">
                                <img
                                    src={logo}
                                    alt="Versus Logo"
                                    className="logo__img"
                                />
                            </NavLink>
                        </div>
                        <p>
                            Versus is a data comparison platform,
                            covering more than 10 categories. Compare
                            universities, cafes, food, telephones, and more.
                        </p>
                    </div>
                    <div className="footer-right"></div>
                </div>
            </div>
        );
    }
}
