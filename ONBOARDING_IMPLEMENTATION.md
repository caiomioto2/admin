# Onboarding Implementation

## Overview
This document outlines the onboarding flow implementation for new users after login. The flow consists of 3 questions that help us understand the user better before they access the admin.

## What's Been Implemented

### 1. Onboarding Questions Page (`/onboarding`)

**Location**: `apps/web/src/components/onboarding/onboarding.tsx`

**Features**:
- Uses the same `SplitScreenLayout` as login for visual consistency
- 3 dropdown questions:
  1. **What is your role?** (Engineering, Product, Marketing, Design, Operations, Sales, Founder/Executive, Other)
  2. **What's the size of your company?** (Just me, 2-25, 26-100, 101-500, 501-1000, 1001+)
  3. **What are you using deco for?** (Make internal apps, Manage MCPs, Create AI SaaS)
- Form validation using `react-hook-form` + `zod`
- Uses existing UI components from `@deco/ui`
- Continue button to submit and proceed to join organizations page

**Route**: `/onboarding`

### 2. Join Organizations Page (`/onboarding/join`)

**Location**: `apps/web/src/components/onboarding/join-organizations.tsx`

**Features**:
- Shows organizations the user can join based on their email domain
- Each org card displays:
  - Organization avatar/icon
  - Organization name
  - Sample member avatars (up to 4)
  - Total member count
  - "Join" button
- "Create new admin" button to skip and create their own org
- Uses the same `SplitScreenLayout` for consistency
- Auto-skips if no joinable organizations available

**Route**: `/onboarding/join`

## Backend Changes Needed

### 1. Database Schema - User Profile

Create a new table for user profile/metadata:

```sql
-- User profile/metadata table
CREATE TABLE user_profile (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT,
  company_size TEXT,
  use_case TEXT,
  onboarding_completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(user_id)
);

-- Index for faster lookups
CREATE INDEX idx_user_profile_user_id ON user_profile(user_id);
CREATE INDEX idx_user_profile_onboarding_completed ON user_profile(onboarding_completed_at);

-- RLS policies
ALTER TABLE user_profile ENABLE ROW LEVEL SECURITY;

-- Users can read their own profile
CREATE POLICY "Users can view own profile"
  ON user_profile
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own profile
CREATE POLICY "Users can insert own profile"
  ON user_profile
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON user_profile
  FOR UPDATE
  USING (auth.uid() = user_id);
```

### 2. Database Schema - Organization Domain Access

Add domain-based access control to organizations:

```sql
-- Add allowed email domains to teams/organizations table
ALTER TABLE teams ADD COLUMN allowed_email_domains TEXT[] DEFAULT '{}';

-- Add index for domain lookups (GIN index for array contains queries)
CREATE INDEX idx_teams_allowed_domains ON teams USING GIN (allowed_email_domains);

-- Example: Update an org to allow @company.com emails
-- UPDATE teams SET allowed_email_domains = ARRAY['@company.com', '@subsidiary.com'] WHERE slug = 'my-org';
```

### 3. API Endpoint - Save Onboarding Profile

**POST `/api/user/onboarding`**

Request body:
```typescript
{
  role: string;
  company_size: string;
  use_case: string;
}
```

Response:
```typescript
{
  success: boolean;
  profile: {
    id: string;
    user_id: string;
    role: string;
    company_size: string;
    use_case: string;
    onboarding_completed_at: string;
  }
}
```

**Implementation tasks**:
1. Validate request body
2. Insert or update user_profile record
3. Set `onboarding_completed_at` = NOW()
4. Track analytics event for onboarding completion (PostHog: `onboarding_completed`)
5. Return profile data

### 4. API Endpoint - Get Joinable Organizations

**GET `/api/user/joinable-organizations`**

Returns organizations that allow the user's email domain:

Request: None (uses authenticated user's email)

Response:
```typescript
{
  organizations: Array<{
    id: number;
    name: string;
    slug: string;
    avatar_url: string;
    member_count: number;
    sample_members: Array<{
      id: string;
      avatar_url: string;
    }>;
  }>;
}
```

**Implementation tasks**:
1. Get authenticated user's email
2. Extract domain from email (e.g., user@company.com → @company.com)
3. Query organizations where user's domain is in `allowed_email_domains` array
4. Get member count and sample member avatars for each org
5. Return list of joinable organizations

**SQL Query Example**:
```sql
SELECT 
  t.id,
  t.name,
  t.slug,
  t.avatar_url,
  COUNT(m.id) as member_count
FROM teams t
LEFT JOIN members m ON m.team_id = t.id AND m.deleted_at IS NULL
WHERE '@company.com' = ANY(t.allowed_email_domains)
GROUP BY t.id;
```

### 5. API Endpoint - Join Organization

**POST `/api/organizations/{org_slug}/join`**

Allows user to join an organization if their email domain is allowed:

Request body: None (uses authenticated user)

Response:
```typescript
{
  success: boolean;
  org: {
    id: number;
    name: string;
    slug: string;
  }
}
```

**Implementation tasks**:
1. Verify user's email domain is in org's `allowed_email_domains`
2. Check if user is not already a member
3. Create member record with default role (not admin)
4. Return org details
5. Throw error if domain not allowed or user already a member

### 6. User Session Check

**GET `/api/user/profile`** (or add to existing user endpoint)

Should return:
```typescript
{
  id: string;
  email: string;
  // ... other user fields
  profile?: {
    role: string;
    company_size: string;
    use_case: string;
    onboarding_completed_at: string | null;
  }
}
```

This is used to determine if user needs to see onboarding.

### 7. Auth Callback Redirect Logic

Update `/auth/callback/magiclink` (in `apps/api/src/auth/index.ts`) to:

1. After successful authentication, check if user has completed onboarding:
   ```typescript
   const profile = await getUserProfile(userId);
   const hasCompletedOnboarding = profile?.onboarding_completed_at !== null;
   ```

2. Redirect logic:
   - If `next` param exists: redirect to `next` (existing behavior)
   - Else if `!hasCompletedOnboarding`: redirect to `/onboarding`
   - Else: redirect to `/` (home page)

## Frontend Integration Needed

### 1. SDK Hook for User Profile

**Location**: `packages/sdk/src/hooks/`

Create `use-user-profile.ts`:

```typescript
import { useQuery, useMutation, queryClient } from "@tanstack/react-query";
import { fetchJSON } from "../fetch";

export interface UserProfile {
  id: string;
  user_id: string;
  role: string;
  company_size: string;
  use_case: string;
  onboarding_completed_at: string | null;
}

export function useUserProfile() {
  return useQuery({
    queryKey: ["user", "profile"],
    queryFn: () => fetchJSON<UserProfile>("/api/user/profile"),
  });
}

export function useUpdateUserProfile() {
  return useMutation({
    mutationFn: (data: { role: string; company_size: string; use_case: string }) =>
      fetchJSON("/api/user/onboarding", {
        method: "POST",
        body: JSON.stringify(data),
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["user", "profile"] });
      queryClient.invalidateQueries({ queryKey: ["user"] });
    },
  });
}
```

### 2. Update Onboarding Component

Replace console.log with actual API call:

```typescript
// In onboarding.tsx
import { useUpdateUserProfile } from "@deco/sdk";

// In component:
const updateProfile = useUpdateUserProfile();

async function onSubmit(data: FormData) {
  setIsSubmitting(true);
  try {
    await updateProfile.mutateAsync({
      role: data.role,
      company_size: data.companySize,
      use_case: data.useCase,
    });
    
    // Track analytics
    trackEvent("onboarding_completed", {
      role: data.role,
      company_size: data.companySize,
      use_case: data.useCase,
    });
    
    navigate("/");
  } catch (error) {
    console.error("Failed to save onboarding data:", error);
    toast.error("Failed to save your profile. Please try again.");
  } finally {
    setIsSubmitting(false);
  }
}
```

### 3. Protected Route Logic (Optional)

If we want to enforce onboarding completion, create a protected route wrapper:

```typescript
// apps/web/src/components/onboarding/require-onboarding.tsx
export function RequireOnboarding({ children }: { children: ReactNode }) {
  const { data: profile, isLoading } = useUserProfile();
  const location = useLocation();
  
  if (isLoading) {
    return <Spinner />;
  }
  
  // If onboarding not completed and not already on onboarding page
  if (!profile?.onboarding_completed_at && location.pathname !== "/onboarding") {
    return <Navigate to="/onboarding" replace />;
  }
  
  return <>{children}</>;
}
```

Then wrap main routes with this component.

## User Flow

1. **User logs in** via email/OAuth → `/login`
2. **Magic link callback** → API checks if onboarding completed
   - If NO: redirect to `/onboarding`
   - If YES: redirect to `/` (home)
3. **User fills onboarding form** → submits 3 questions (`/onboarding`)
4. **API saves profile** → marks `onboarding_completed_at`
5. **Check for joinable orgs** → API returns orgs based on email domain
   - If joinable orgs exist: redirect to `/onboarding/join`
   - If no joinable orgs: redirect to `/` (home)
6. **Join organizations page** (`/onboarding/join`)
   - User can join existing orgs or skip
   - Click "Join" → user becomes member of that org → redirected to `/{org_slug}`
   - Click "Create new admin" → redirected to `/` where they can create their own org

## Testing Checklist

- [ ] New user can access `/onboarding` page
- [ ] Form validation works (all fields required)
- [ ] Dropdown selections work correctly
- [ ] Continue button submits form
- [ ] API endpoint saves profile data
- [ ] `onboarding_completed_at` timestamp is set
- [ ] After onboarding, user redirected to home
- [ ] Existing users (with completed onboarding) skip `/onboarding`
- [ ] Analytics event fires on completion
- [ ] Page matches Figma design

## Next Steps

1. Create database migration for `user_profile` table
2. Implement `/api/user/onboarding` endpoint
3. Add profile to user session/context
4. Update auth callback redirect logic
5. Create SDK hooks for profile management
6. Wire up API call in onboarding component
7. Add analytics tracking
8. Test full flow with new and existing users

## Files Changed

- ✅ `apps/web/src/components/onboarding/onboarding.tsx` (new - questions page)
- ✅ `apps/web/src/components/onboarding/join-organizations.tsx` (new - join orgs page)
- ✅ `apps/web/src/main.tsx` (added routes)
- ⏳ `packages/sdk/src/hooks/use-user-profile.ts` (needs creation)
- ⏳ `packages/sdk/src/hooks/use-joinable-organizations.ts` (needs creation)
- ⏳ `apps/api/src/auth/index.ts` (needs update)
- ⏳ Database migrations (needs creation)

