import { defineConfig } from 'vite'
import elmPlugin from 'vite-plugin-elm'

export default defineConfig({
  publicDir: 'public',
  plugins: [elmPlugin()]
})
