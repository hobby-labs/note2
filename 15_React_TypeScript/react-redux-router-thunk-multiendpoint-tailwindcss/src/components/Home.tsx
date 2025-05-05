import React from 'react';

type HomeProps = {
  name: string;
}

const Home: React.FC<HomeProps> = ({ name }) => {
    return (
        <div className="grid grid-cols-1 mx-auto max-w-7xl justify-between lg:px-8">
            <h1 className="text-2xl">{name} in component.</h1>
            This is a test page.
        </div>
    );
}

export default Home;
