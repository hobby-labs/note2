import React from 'react';
import { BrowserRouter as Router, Route, Routes, Link } from 'react-router-dom';
import Home from './components/Home';
import Data from './components/Data';

const App: React.FC = () => {
    return (
        <Router>
            <nav>
                <Link to="/">Home</Link> | <Link to="/data">Data</Link>
            </nav>
            <Routes>
                <Route path="/" element={<Home name="PropHome" />} />
                <Route path="/data" element={<Data />} />
            </Routes>
        </Router>
    );
};

export default App;