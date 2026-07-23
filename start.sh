#!/bin/bash
set -a
source /opt/puls-backend/.env
set +a
exec node /opt/puls-backend/server.js
