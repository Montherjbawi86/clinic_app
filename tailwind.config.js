/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/views/**/*.{erb,html,ruby}",
    "./app/helpers/**/*.rb",
    "./app/javascript/**/*.js",
    "./app/assets/stylesheets/**/*.css",
  ],
  theme: {
    extend: {
      colors: {
        primary: "#0d9488",
      },
    },
  },
  plugins: [],
};
