import { createClient } from '@supabase/supabase-js';
import { createOfflineFetch, initOfflineSync } from './offline';

const supabaseUrl = 'https://wsfokyryygdejepjvhym.supabase.co';
const supabaseAnonKey = 'sb_publishable_j60iHnmTvv-evZdlERVpIA_DoYnY_Fs';

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  global: { fetch: createOfflineFetch() },
  auth: { persistSession: true, autoRefreshToken: true },
});

initOfflineSync({
  getSession: () => supabase.auth.getSession() as never,
  refreshSession: () => supabase.auth.refreshSession(),
});
