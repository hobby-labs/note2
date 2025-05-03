import React from 'react';

type HomeProps = {
  name: string;
}

const Home: React.FC<HomeProps> = ({ name }) => {
    return <h1 className="text-2xl">{name} in component.</h1>
}

export default Home;