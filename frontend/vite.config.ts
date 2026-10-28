import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// The production build goes straight into Rails' public/ folder, so one server serves both.
export default defineConfig({
  plugins: [react()],
  build: { outDir: '../public', emptyOutDir: true },
  server: {
    proxy: {
      '/api': 'http://localhost:3000',
      '/webhooks': 'http://localhost:3000',
    },
  },
})
