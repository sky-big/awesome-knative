# ForwardedShim Handler功能解析

```
/serving/pkg/queue/forwarded_shim.go

func ForwardedShimHandler(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer h.ServeHTTP(w, r)

		// Forwarded: by=<identifier>;for=<identifier>;host=<host>;proto=<http|https>
		fwd := r.Header.Get("Forwarded")

		// Don't add a shim if the header is already present
		if fwd != "" {
			return
		}

		// X-Forwarded-For: <client>, <proxy1>, <proxy2>
		xff := r.Header.Get("X-Forwarded-For")
		// X-Forwarded-Proto: <protocol>
		xfp := r.Header.Get("X-Forwarded-Proto")
		// X-Forwarded-Host: <host>
		xfh := r.Header.Get("X-Forwarded-Host")

		// Nothing to do if we don't have any x-fowarded-* headers
		if xff == "" && xfp == "" && xfh == "" {
			return
		}

		// The forwarded header is a list of forwarded elements
		elements := []string{}

		// The x-forwarded-header consists of multiple nodes
		nodes := strings.Split(xff, ",")

		// Sanitize nodes
		for i, node := range nodes {
			// Remove extra whitespace
			node = strings.TrimSpace(node)

			// For simplicity, an address is IPv6 it contains a colon (:)
			if strings.Contains(node, ":") {
				// Convert IPv6 address to "[ipv6 addr]" format
				node = fmt.Sprintf("\"[%s]\"", node)
			}

			nodes[i] = node
		}

		// The first element has a 'for', 'proto' and 'host' pair, as available
		pairs := []string{}

		if xff != "" {
			pairs = append(pairs, "for="+nodes[0])
		}
		if xfh != "" {
			pairs = append(pairs, "host="+xfh)
		}
		if xfp != "" {
			pairs = append(pairs, "proto="+xfp)
		}

		// The pairs are joined with a semi-colon (;) into a single element
		elements = append(elements, strings.Join(pairs, ";"))

		// Each subsequent x-forwarded-for node gets its own pair element
		for _, node := range nodes[1:] {
			elements = append(elements, "for="+node)
		}

		// The elements are joined with a comma (,) to form the header
		fwd = strings.Join(elements, ", ")

		// Add forwarded header
		r.Header.Set("Forwarded", fwd)
	})
}
```