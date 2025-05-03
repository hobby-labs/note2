import React from 'react';
import { PopoverGroup } from '@headlessui/react';
import { BrowserRouter as Router, Route, Routes, Link } from 'react-router-dom';
import Home from './components/Home';
import Data from './components/Data';
import Logo from './svgs/Flower';

const App: React.FC = () => {
    return (
        <Router>
            <header>
                <nav aria-label="Global" className="mx-auto flex items-center justify-between p-6 lg:px-8">
                    <div className="flex lg:flex-1">
                        <Link to="/" className="text-sm/6 font-semibold"><Logo className="w-10" /></Link>
                        <span className="justify-items-end p-1 lg:px-4">テストサイト</span>
                    </div>
                    <div className="flex items-stretch grid-cols-2 gap-8">
                        <div className="py-1"><Link to="/" className="text-sm/6 font-semibold">Home</Link></div>
                        <div className="py-1"><Link to="/data" className="text-sm/6 font-semibold">Data</Link></div>
                    </div>
                </nav>
            </header>
            <Routes>
                <Route path="/" element={<Home name="PropHome" />} />
                <Route path="/data" element={<Data />} />
            </Routes>
        </Router>
    );
};

export default App;