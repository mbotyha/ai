// Destroys short-lived servers whose time is up, with their DNS record, every 5 minutes (cron),
// so they go away with the laptop off. A server opts in with two Vultr tags, set by
// `jitsi-vultr create --duration`: "expires=<unix seconds>" and "fqdn=<host name>".
// Secrets: VULTR_API_KEY (API access control must allow any IP), CLOUDFLARE_API_TOKEN (Zone Read + DNS Edit).

const call = (base, token) => async (path, init = {}) => {
  const res = await fetch(base + path, { ...init, headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' } })
  if (!res.ok) throw new Error(`${init.method || 'GET'} ${path}: ${res.status}`)
  return res.status === 204 ? null : res.json()
}

const tag = (inst, key) => inst.tags?.find(t => t.startsWith(`${key}=`))?.slice(key.length + 1)

// Deletes the A record only while it still points at this server
const dropDns = async (cf, fqdn, ip) => {
  const parts = fqdn.split('.')
  for (let i = 1; i < parts.length - 1; i++) {
    const { result: [zone] } = await cf(`/zones?name=${parts.slice(i).join('.')}`)
    if (!zone) continue
    const { result } = await cf(`/zones/${zone.id}/dns_records?type=A&name=${fqdn}`)
    for (const rec of result.filter(r => r.content === ip)) await cf(`/zones/${zone.id}/dns_records/${rec.id}`, { method: 'DELETE' })
    return
  }
}

export const reap = async (env, now = Date.now() / 1000) => {
  const vultr = call('https://api.vultr.com/v2', env.VULTR_API_KEY)
  const cf = call('https://api.cloudflare.com/client/v4', env.CLOUDFLARE_API_TOKEN)
  // ponytail: first 500 instances, cursor pagination if the account ever gets past that
  const { instances } = await vultr('/instances?per_page=500')
  const reaped = []
  for (const inst of instances) {
    const expires = Number(tag(inst, 'expires'))
    if (!expires || expires > now) continue
    const fqdn = tag(inst, 'fqdn')
    // DNS first: the record must never outlive the IP, which Vultr hands to someone else
    if (fqdn) await dropDns(cf, fqdn, inst.main_ip)
    await vultr(`/instances/${inst.id}`, { method: 'DELETE' })
    reaped.push(`${inst.label} ${inst.main_ip}${fqdn ? ` ${fqdn}` : ''}`)
  }
  return reaped
}

export default {
  scheduled: (event, env, ctx) => ctx.waitUntil(reap(env).then(r => r.length && console.log('reaped', r)))
}
