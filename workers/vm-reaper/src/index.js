// Destroys short-lived servers whose time is up, with their DNS record, every 5 minutes (cron),
// so they go away with the laptop off. A server opts in with two Vultr tags, set by
// `jitsi create --duration`: "expires=<unix seconds>" and "fqdn=<host name>".
// Secrets: VULTR_API_KEY (API access control must allow any IP), CLOUDFLARE_API_TOKEN (Zone Read + DNS Edit).

const call = (base, token) => async (path, init = {}) => {
  const res = await fetch(base + path, { ...init, headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' } })
  if (!res.ok) throw new Error(`${init.method || 'GET'} ${path}: ${res.status}`)
  return res.status === 204 ? null : res.json()
}

const tag = (inst, key) => inst.tags?.find(t => t.startsWith(`${key}=`))?.slice(key.length + 1)

// Same rule as jitsi.sh cost(): monthly/672 per started hour, capped at the monthly price
const cost = (plans, inst, now) => {
  const p = plans.find(x => x.id === inst.plan)
  const monthly = p?.location_cost?.[inst.region]?.monthly_cost ?? p?.monthly_cost
  if (!monthly) return ''
  const hours = Math.ceil((now - Date.parse(inst.date_created) / 1000) / 3600)
  return ` ${hours}h ${Math.min(hours * monthly / 672, monthly).toFixed(2)}USD`
}

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
  const expired = instances.filter(inst => Number(tag(inst, 'expires')) && Number(tag(inst, 'expires')) <= now)
  // prices only for the log line: a failed lookup must not stop the destroy
  const plans = expired.length ? (await vultr('/plans?per_page=500').catch(() => ({}))).plans || [] : []
  for (const inst of expired) {
    const fqdn = tag(inst, 'fqdn')
    // one failing server must not keep the others billing: report it and go on
    try {
      // DNS first: the record must never outlive the IP, which Vultr hands to someone else
      if (fqdn) await dropDns(cf, fqdn, inst.main_ip)
      await vultr(`/instances/${inst.id}`, { method: 'DELETE' })
      reaped.push(`${inst.label} ${inst.main_ip}${fqdn ? ` ${fqdn}` : ''}${cost(plans, inst, now)}`)
    } catch (err) {
      console.error('reap failed', inst.label, err.message)
    }
  }
  return reaped
}

export default {
  scheduled: (event, env, ctx) => ctx.waitUntil(reap(env).then(r => r.length && console.log('reaped', r)))
}
