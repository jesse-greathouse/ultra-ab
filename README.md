# Ultra Mobile Assignment

I have been asked by Ultra Mobile to create a software project. This document defines the specific tasks for this assignment.

## Create a working local environment

The environment must have the following components:

1. WordPress Site  
2. Two Micro Frontends  
   - One front end must be a NextJS application with an App or Page Router hosted on a path.  
3. Database Server  
4. API Server  
5. Dynamic Routing based on rules and traffic allocation

## Achieve the following goal with the software environment

The business needs constant A/B testing to test new features and experiences. We want to be able to serve multiple experiences on the frontend using the micro frontends.

### Do the testing distribution with the following parameters

20% of users to micro frontend A  
30% of users to micro frontend B  
50% of users to the Control (WordPress frontend)

## Document the followng

### How would you set up the Infrastructure?

### How would you make sure this experience is optimized and backends can be served quickly and efficiently?

### How would you measure traffic going to the different backends and gather the amount of visitors being sent there?

### How would you make decisions on what Backend to serve to a certain viewer?

### Can you list the pros and cons of your approach?

## Notes on the approach

I’m documenting my thought process here to provide clarity on how I make decisions per this assignment.

### Problem Summary

- Bucket users into consistent testing groups (A, B, Control).  
- Route them deterministically on **every request** based on prior assignment.  
- Ensure that assignments **persist across restarts**.  
- Minimize latency in the routing decision.  
- Avoid disk-based hacks or slow SQL lookups at the edge.  
- Use **OpenResty (Nginx+Lua)** in a containerized context.

### Assumptions

- Shared memory across containers is not available → `lua_shared_dict` is per Nginx instance.  
- MySQL is too slow for hot-path routing decisions.  
- Flat files are fragile and not appropriate for concurrency or durability.  
- **Redis is ideal for speed**, but default Redis without AOF/RDB configuration will **lose state** on restart.

### Strategic Design Direction

Use **Redis as a session assignment store**, with:

- **AOF persistence** enabled (`appendonly yes`)  
- **Eviction policy** set to `noeviction` or `volatile-lru`, depending on scale  
- **Namespace** or key-prefix strategy like: `abtest:{session_id} → A|B|Control`

### Lifecycle of a Request

1. Incoming Request to OpenResty  
     - Extract session identifier (cookie or generated)  
     - Lookup in Redis for existing bucket assignment  
2. **If exists** → Route accordingly (100µs roundtrip)  
3. **If missing**:  
     - Use deterministic weighted logic (e.g., math.random \+ thresholds)  
     - Assign bucket (e.g., “B”)  
     - Persist to Redis (`SET abtest:{session_id} "B"`)  
     - Route accordingly  
4. Downstream applications will record the properties and results of their test distribution back to the MySQL database.

### Architectural Cohesion

#### Distribution (OpenResty \+ Lua \+ Redis)

- Stateless except for lookup \+ assignment  
- Fast (sub-ms routing)  
- Deterministic (via Redis persistence)  
- Decoupled from application-level semantics

#### Conversion/Outcome Tracking (App Logic \+ API → MySQL)

- Each MFE (**Micro Frontend**) is responsible for reporting its own success/failure  
- Conversion criteria are contextualized within the app (correctly)  
- Data goes to MySQL, not Redis, because conversions:  
  - Are infrequent relative to routing decisions  
  - Require durability and historical analysis

## System Architecture Flow Diagram

### [View the Diagram on Lucid](https://lucid.app/lucidchart/23d074ec-10e6-4bae-bb1b-f7ca1bd499d7/edit?viewport_loc=-576%2C385%2C4377%2C1938%2C0_0&invitationId=inv_932973de-8871-49ff-92fd-223055a902e7)

### **Architectural Overview**

- OpenResty (NGINX \+ LuaJIT) serves as the centralized API gateway and request router.  
  - Handles all incoming user traffic.  
  - Custom Lua code executed in the Nginx worker algorithmically assigns user sessions to A/B test buckets using data from a persistent Redis-backed session store.  
  - Proxies requests to one of three upstream applications:  
    - WordPress (Control group)  
    - Next.js frontend (Test Group A)  
    - Vue 3 frontend (Test Group B)  
- Session-based routing ensures deterministic user experience throughout the test lifecycle.  
  - New sessions are assigned buckets on first request.  
  - Subsequent requests reuse the stored assignment from Redis.  
- Each frontend application is responsible for:  
  - Detecting meaningful conversions within its context.  
  - Posting atomic test results (including session ID and bucket) to OpenResty via a tracking API.  
  - Atomic test results include the state of conversion or non-conversion.  
- OpenResty exposes lightweight API endpoints for:  
  - Session lookup and test assignment.  
  - Tracking request metadata and conversion events.  
- Tracking data is written to MySQL for durable storage and analysis and reporting.  
  - Includes `request_id`, `did_convert` flag, and `timestamp`.  
  - Enables post-hoc evaluation of test performance across variants.
