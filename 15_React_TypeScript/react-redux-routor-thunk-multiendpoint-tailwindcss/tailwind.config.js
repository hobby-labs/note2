module.exports = {
    // content: ['./dist/*.html'],
    content: ['./src/**/*.{html,js,jsx,ts,tsx}'],
    //darkMode: 'media', // or 'media' or 'class'

    theme: {
        extend: {
            colors: {
                customBlue: '#00a0e9',
            },
            spacing: {
                '128': '32rem',
            },
            fontFamily: {
                sans: ['Inter', 'sans-serif'],
            }
        }
    },
    variants: {
        extend: {}
    },
    plugins: []
}