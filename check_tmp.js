import 'dotenv/config';
import crypto from 'node:crypto';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

const apiKey = 'pk_live_REDACTED';
const hashedKey = crypto.createHash('sha256').update(apiKey).digest('hex');

async function check() {
  const { data: userRecord, error } = await supabase.from('users').select('*').eq('api_key_hash', hashedKey).maybeSingle();
  if (error) console.error(error);
  console.log('User:', userRecord);

  if (userRecord) {
    const { data: wallet } = await supabase.from('wallets').select('*').eq('user_id', userRecord.id);
    console.log('Wallets:', wallet);
  }
}

check();
