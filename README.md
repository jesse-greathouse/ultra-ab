# Ultra Mobile Assignment

I have been asked by Ultra Mobile to create a software project. This document defines the specific tasks for this assignment.

## How to install

### System requirements

The following system dependencies are required to run the project.

- [Perl 5](https://www.perl.org/) and [cpanm](https://metacpan.org/dist/App-cpanminus/view/bin/cpanm)
- [Docker](https://docs.docker.com/get-started/get-docker/) with [docker compose](https://docs.docker.com/compose/)
- [PHP 8.2+](https://www.php.net/)
- [Node.js 22.17 LTS](https://nodejs.org/en) and hopefully [managed with NVM](https://github.com/nvm-sh/nvm)

### Follow these steps to install the project:

1. `git clone git@github.com:jesse-greathouse/ultra-ab.git`
2. `cd ultra-ab`
3. `bin/bootstrap`
    > The bootstrap script will walk through all the system requirements, notify you about any missing dependencies and install all of the required bootstrapping packages.
4. `bin/configure`
    > The configure script will set up the runtime configuration, ask you for all of the required environment strings, and prepare the docker-compose.yml file.
  
### Interactive Configuration

#### Deployment Mode

![Deployment Mode](https://i.imgur.com/bUFzQwd.png)

At this time only 1. Docker Compose is supported (I have not had time to QA the system install deployment).

#### WordPress and Webserver specifications

![Specifications](https://i.imgur.com/cxNN8qE.png)

- *Admin Email Address* - This is the email address of the WordPress site administrator.
- *Server Host Names* - This is the string of host names or IPs that go in the Nginx server directive.
- *Web Server Port* - The port that you will access the application at.
- *Site Title* - The Site heading in WordPress
- *Site URL* - The full Web Address of your site URL (Needed for WordPress)
- *Enable Debugging* - Flag to enable full debug logging.

#### Generating DH Parameters

![Dh-params](https://i.imgur.com/mDeeNTm.png)

> Woa! what the heck?

The [Diffie-Hellman Param is a cryptographic entropy enhancement](https://wiki.openssl.org/index.php/Diffie-Hellman_parameters) that is used for securing the TLS 1.3 SSL feature of nginx. It takes a minute to complete, but it will only run once, and it wont need to run again unless you delete the file it creates.

#### WordPress Codebase Check

If the WordPress code is not detected, you will be asked to select a WordPress version.
![WordPress Codebase Check](https://i.imgur.com/nZeU2I1.png)

Once you have selected a WordPress version, it will install that version.

![WordPress Install](https://i.imgur.com/5eoLbOi.png)

#### WordPress CLI install

The [wp-cli](https://wp-cli.org/) WordPress command line tool is a utility that this project makes heavy use of. The project will install the wp-cli with composer.

![wp-cli](https://i.imgur.com/CpO0Tck.png)

#### WordPress Skeleton

This project uses a WordPress Skeleton which is the operative part of the WordPress code which will be checked in and version controlled. It's the only place where WordPress code will be persistent in the project. This is the place to put plugins, themes, assets and custom code.

![WordPress Skeleton](https://i.imgur.com/e359sIt.png)

The WordPress skeleton code can be found under `src/wordpress-skeleton`

### WordPress Database Installation

Once the WordPress code has been installed, it's now time to install the WordPress database.

![WordPress Database Installation](https://i.imgur.com/y6pC01Q.png)

The script will start the Docker database container and check to see if the database has already been installed. If the database has not been installed, it will ask you to provide the admin username and the password for your admin user.
> You can change the admin password later if you forget it by running the `bin/configure` script again.

### WordPress Database Backup

A backup copy of the WordPress Database will be created every time the configure script is ran. This is a safeguard to ensure that any changes can be reverted to a previous state.

![WordPress Database Backup](https://i.imgur.com/JkVV2OH.png)

A database backup can be run at any time using the `bin/db-backup` script.

> The backup file gets archived and placed in `var/db_backups`

#### Database Migrations

In addition to installing and backing up the WordPress database, there is also a feature for Migrating tables, including those tables involved in the A/B testing application.

![Database Migrations](https://i.imgur.com/zpki9Rv.png)

The database migrations can be run later with the script `bin/migrate`

> To create a new database migration, use the script `bin/make-migration` which will create a file in `src/sql/migrations`

#### WordPress Application Password

The application can use WordPress in headless form, through either of its two Microfrontends (MFE). In order to use the WordPress Rest API, an Application Password must be created so the MFEs can authenticate. If an Application Password does not yet exist, one will be created through automation, and assigned to an environment variable called: APPLICATION_SECRET.

![WordPress Application Password](https://i.imgur.com/6jLr7jY.png)

#### Admin Password Change

This prompt in the configuration sequence is meant to provide a way that you can change the administrator password if you forgot it, or if it has become compromised.

![Admin Password Change](https://i.imgur.com/ZapwMi9.png)

#### Composer Install for Plugins and Themes

If your WordPress Skeleton has plugins and themes which require a [Composer](https://getcomposer.org/) install sequence, this is the step in which the script will audit all of the relevant directories and run a `composer install` in the context of the directory if it finds a Composer manifest.

![Composer Install](https://i.imgur.com/MzDZrE8.png)

#### Building Micro-Frontends

If its the first time you have run the configuration script, this is the point in which the MFEs will be built with [NPM](https://docs.npmjs.com/about-npm). If it's not the first time that the configure script has been run, you will be prompted if you would like to build the MFEs.

![Building Micro-Frontends](https://i.imgur.com/efROJLL.png)

#### Completion

Once the configuration sequence is complete, you will be given instructions on how to run docker compose to operate your application.

![Completion](https://i.imgur.com/beXNSCa.png)

## Running the Application

Once the application is configured, It can be run and controlled with docker compose in the following ways:

- `docker compose up -d`        - Launch all containers in the background
- `docker compose down`         - Stop and remove containers
- `docker compose ps`           - Show running services
- `docker compose logs -f`      - View live logs from all services
- `docker compose restart`      - Restart all services

![Running Ultra AB](https://i.imgur.com/cWkT8LO.png)

It's a good idea to go straight to your [WordPress Admin Dashboard](https://wordpress.com/support/dashboard/) by going to he url followed by /wp-admin

![WordPress Admin Dashboard Login](https://i.imgur.com/3JEV280.png)

Once you login, you can change the theme or manage plugins.

![WordPress Admin Dashboard](https://i.imgur.com/8Tt2DFB.png)

## Using Other Frontends

There are two other MFE (Micrro-Frontends) available in the project, one is built with [Next.js](https://nextjs.org/) and the other is built with [Vue 3](https://vuejs.org/).

### Rotating the session

The system is designed to A/B test different Front-Ends. When a session is esablished, the application will stick with the front-end assigned with that session. In order to change which Front-end gets selected, you have to rotate the session.

The session is coordinated in your browser with a cookie called: `ab_sid`. If you delete the cookie, the server should issue a new session when you refresh the page. If another front-end is due to be tested, you may get a different frontend associated with your new session.

![ab_sid Cookie](https://i.imgur.com/RQSkBLP.png)

![Delete Cookie](https://i.imgur.com/QsGsE2k.png)

![Next-js](https://i.imgur.com/wH59qLt.png)

### Going Directly to the Frontend

In addition to rotating the session, if you'd like to go directly to the front end, there are helpful endpoints for `/next` and `/vue` which will take you to the respective frontend that you want to see.

![Vue](https://i.imgur.com/Dc6jQ3w.png)

## Testing Allocations

The business needs constant A/B testing to test new features and experiences. We want to be able to serve multiple experiences on the frontend using the micro frontends.

### The testing distribution follows these parameters

20% of users to micro frontend A  
30% of users to micro frontend B  
50% of users to the Control (WordPress frontend)

### Test Distribution Script

Because it's extremely tedious to delete cookies and refresh the browser and track how accurate the distribution is in that way, I have created a script that programmatically spams the app and continues to get new sessions until it has hit the target number of sessions.

`bin/test-distribution --total_sessions=n --throttle=s`

You can use this script to spam any number of sessions with the `--total-sessions option`.

When the script is finished creating the target number of sessions, it will report the distribution of of which frontends were served.

the `--throttle` option will allow you to specify seconds or a fraction of a second between requests in case running the script is very hard on your computer.

![Distribution Test](https://i.imgur.com/ZDfmwWU.png)

I have run the test many times and the distribution is always right on target. The algorithm is just really, really rock solid and it executes very efficiently. Nginx likes to be verry sticky with sessions so it usually takes about 3X as many requests to get the right amount of sessions, but the script only tracks distinct sessions, so the extra requests do not get counted.

### The Algorithm

The module `src/lua/jessegreathouse/ultraab/lib/ab/maanager.lua` is the manager of the control flow and it has code that programs the algorithm:

```lua
--[[
Testing Distribution:

  This algorithm assigns each new session to one of three buckets (A, B, or C) in a way that keeps the real-world distribution of users as close as possible to your target percentages:

    - 20% of sessions should be in bucket A
    - 30% of sessions should be in bucket B
    - 50% of sessions should be in bucket C

  Here’s how it works:

    1. We check how many sessions have already been assigned to A, B, and C.
    2. We calculate the current percentages for each bucket (A, B, C).
    3. We compare the actual percentage for each bucket to its target percentage.
    4. The bucket that is furthest *below* its target gets the next user.
      - If there’s a tie (two or more buckets equally under target), we pick C first, then A, then B.
    5. If all buckets are already at or above their targets, we still pick C by default.

  This way, as more sessions come in, the system keeps the overall distribution tracking your target split, and naturally “catches up” any bucket that falls behind.
]]
function _M:select_bucket_based_on_distribution()
  -- Query current stats
  local total_sessions = self.stats.get_session_count() or 0
  local total_a = self.stats.get_bucket_a_count() or 0
  local total_b = self.stats.get_bucket_b_count() or 0
  local total_c = total_sessions - (total_a + total_b)
  if total_c < 0 then total_c = 0 end -- Defensive

  -- Calculate distributions, guarding division by zero
  local d_a, d_b, d_c = 0, 0, 0
  if total_sessions > 0 then
    d_a = total_a / total_sessions
    d_b = total_b / total_sessions
    d_c = total_c / total_sessions
  end

  -- Define targets
  local targets = { A = 0.20, B = 0.30, C = 0.50 }
  local current = { A = d_a,   B = d_b,   C = d_c  }
  local gaps = {}
  for k, target in pairs(targets) do
    gaps[k] = target - (current[k] or 0)
  end

  -- Candidates: only buckets under their target
  -- Preference order: C, A, B (so sort order matters on ties)
  local order = { "C", "A", "B" }
  local best, best_gap = "C", gaps["C"]
  for _, k in ipairs(order) do
    if gaps[k] > 0 and (best == nil or gaps[k] > best_gap or (gaps[k] == best_gap and k == order[1])) then
      best = k
      best_gap = gaps[k]
    end
  end

  -- If all buckets at/above target (gaps <= 0), still prefer "C" by default
  return best
end
```

## Architectural Thesis

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
