// Runnable check with a fake fetch: node workers/vm-reaper/check.mjs
import assert from 'node:assert/strict'
import { reap } from './src/index.js'

const calls = []
const json = body => new Response(JSON.stringify(body), { status: 200 })
globalThis.fetch = async (url, init = {}) => {
  const u = new URL(url); const m = init.method || 'GET'
  calls.push(`${m} ${u.pathname}${u.search}`)
  if (u.pathname === '/v2/instances') return json({ instances: [
    { id: 'old', label: 'bitvero-jitsi', main_ip: '1.2.3.4', tags: ['jitsi', 'expires=100', 'fqdn=bitvero.mbotyha.com'] },
    { id: 'new', label: 'later-jitsi', main_ip: '5.6.7.8', tags: ['expires=999999', 'fqdn=later.mbotyha.com'] },
    { id: 'keep', label: 'pay', main_ip: '9.9.9.9', tags: [] }
  ] })
  if (u.pathname === '/client/v4/zones') return json({ result: u.searchParams.get('name') === 'mbotyha.com' ? [{ id: 'z' }] : [] })
  if (u.pathname === '/client/v4/zones/z/dns_records' && m === 'GET') return json({ result: [{ id: 'r1', content: '1.2.3.4' }, { id: 'r2', content: '7.7.7.7' }] })
  return new Response(null, { status: 204 })
}

const reaped = await reap({ VULTR_API_KEY: 'k', CLOUDFLARE_API_TOKEN: 't' }, 500)
assert.deepEqual(reaped, ['bitvero-jitsi 1.2.3.4 bitvero.mbotyha.com'])
const deletes = calls.filter(c => c.startsWith('DELETE'))
assert.deepEqual(deletes, ['DELETE /client/v4/zones/z/dns_records/r1', 'DELETE /v2/instances/old'])
console.log('vm-reaper check ok')
