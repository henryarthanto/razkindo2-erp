// PM2 Process Manager Configuration
// Usage:
//   pm2 start ecosystem.config.cjs
//   pm2 stop all
//   pm2 restart all
//   pm2 logs
//   pm2 monit

module.exports = {
  apps: [
    {
      name: 'razkindo-erp',
      script: 'node_modules/.bin/next',
      args: 'start',
      cwd: __dirname,
      instances: 1, // Single instance (Next.js handles its own optimization)
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '512M',
      env: {
        NODE_ENV: 'production',
        PORT: 3000,
      },
      env_development: {
        NODE_ENV: 'development',
        PORT: 3000,
      },
      // Logging
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      error_file: './logs/pm2-error.log',
      out_file: './logs/pm2-out.log',
      merge_logs: true,
      // Graceful shutdown
      kill_timeout: 5000,
      listen_timeout: 10000,
      shutdown_with_message: true,
    },
    {
      name: 'event-queue',
      script: 'mini-services/event-queue/index.ts',
      interpreter: 'node_modules/.bin/bun',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '256M',
      env: {
        NODE_ENV: 'production',
        PORT: 3004,
      },
      env_development: {
        NODE_ENV: 'development',
        PORT: 3004,
      },
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      error_file: './logs/event-queue-error.log',
      out_file: './logs/event-queue-out.log',
      merge_logs: true,
      kill_timeout: 3000,
    },
  ],
};
