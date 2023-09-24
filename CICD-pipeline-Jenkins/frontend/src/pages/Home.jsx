import React, { Component } from 'react';

import { Banner, CategoryBlock } from '../components';

export default class Home extends Component {
    render() {
        return (
            <>
                <Banner
                    title="VERSUS"
                    description={[
                        'Comparison platform covering over 10 categories.',
                        <br />,
                        'Compare universities, cafes, food, phones, and more.',
                    ]}
                />
                <CategoryBlock />
            </>
        );
    }
}
