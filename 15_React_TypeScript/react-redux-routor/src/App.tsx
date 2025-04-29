import React from 'react';
import { BrowserRouter as Router, Route, Routes, Link } from 'react-router-dom';
import Home from './components/Home';
import Counter from './components/Counter';

const App: React.FC = () => {
    return (
        <Router>
            <nav>
                <Link to="/">Home</Link> | <Link to="/counter">Counter</Link>
            </nav>
            <Routes>
                <Route path="/" element={<Home name="PropHome" />} />
                <Route path="/counter" element={<Counter />} />
            </Routes>
        </Router>
    );
};

export default App;