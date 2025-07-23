# Fly.io static egress IP proxy

## Why is this needed?

Fly.io provides static egress IP addresses so requests your machines make
originate in a stable IPv4 address.

This is typically needed for allowlist-based access control.

This is required because otherwise, the egress IP address of requests made from
a Fly machine is somewhat unpredictable and subject to change for operational
reasons.

However, static egress IPs are bound to specific _machines_, not _apps_, which
carries a number of complications:

* Costly if you have a large number of machines and want to give an egress IP
  to each
* When a machine is destroyed, the egress IP is released and can't be
  reclaimed. This interferes with:
    * Everyday machine creation, which is a _very_ common operation on Fly.io.
    * Everyday machine _destruction_ - when IPs disappear from your list.
    * bluegreen deploys which destroy all your old machines and create new ones
      to replace them.

## What does this do?
This repository and instructions help you create an additional fly application
running a simple HTTP proxy with two machines each with a static egress IP
address.

Then you can set all your other apps up to route any outbound HTTP/S requests
through the Proxy app, therefore making requests appear to come from those
fixed IP addresses.

The proxy app's machines can be just left running all the time while the other
apps' machines can be freely destroyed/created, deployed, etc. They can change,
but the proxy app's machines don't change.

Running two shared-1x 256MB machines is enough for a moderate-to-high volume of
requests and should cost about $5/month for the machines themselves.



## How do I use it?

```bash
export PROXY_NAME=your-proxy-name
fly app create $PROXY_NAME -o your-organization
fly deploy --no-public-ips -a $PROXY_NAME
fly ips allocate-v6 --private -a $PROXY_NAME
for m in $(fly machines list -a $PROXY_NAME --json  | jq -r '.[] | .id'); do fly machine egress-ip allocate -a $PROXY_NAME --yes $m; done
```

Lastly, point your apps to the proxy for outbound http/https requests. In your
other apps do something like setting the http_proxy and https_proxy environment
variables to `http://your-proxy-name.flycast:8888`.

The above is app-dependent, most decent request libraries (libcurl, notably)
honor the environment variables, but others may need to have the proxy
configured explicitly.

# How does it work?

You're creating a Fly app with two machines. Requests should be distributed
somewhat evenly among the two machines. You're setting up the app to _not_ be
exposed to the Internet (it'd be an open proxy!). You're giving the app a
_private_ IP address so it's usable by any other apps within your organization
at the `$PROXY_NAME.flycast` hostname. Then you're assigning a static
egress IP to both machines in this app.

Those are the egress IPs you need to share with anyone needing to allowlist
your requests: see the IPs with `fly machines egress-ip list -a your-proxy-app`.

The proxy fly app runs a very simple HTTP/HTTPS proxy
(https://tinyproxy.github.io/). This is run in the default configuration from a
Docker image - if you need to customize Tinyproxy's configuration you can use a
custom Dockerfile and config files.

# Caveats

* It's entirely _unsupported_ - it's just an example of how to configure a
  private-only proxy on Fly.io.
* Only handles http/https.
* Extra latency, expect HTTP requests to have about 100ms extra round-trip time
  due to the proxy hop.
