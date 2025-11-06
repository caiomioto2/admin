import { useState } from "react";
import { useNavigate } from "react-router";
import { Button } from "@deco/ui/components/button.tsx";
import { Icon } from "@deco/ui/components/icon.tsx";
import { Avatar } from "../common/avatar";
import { SplitScreenLayout } from "../login/layout.tsx";
import { useCreateTeam, queryClient } from "@deco/sdk";
import { QueryClientProvider } from "@tanstack/react-query";

// Fun adjectives and nouns for random org names
const ADJECTIVES = [
  "Magic",
  "Cosmic",
  "Happy",
  "Swift",
  "Bright",
  "Golden",
  "Silver",
  "Crystal",
  "Mystic",
  "Noble",
  "Rapid",
  "Stellar",
  "Lucky",
  "Mighty",
  "Clever",
  "Bold",
  "Wild",
  "Cool",
  "Epic",
  "Super",
  "Mega",
  "Ultra",
  "Turbo",
  "Hyper",
];

const NOUNS = [
  "Unicorn",
  "Dragon",
  "Phoenix",
  "Tiger",
  "Eagle",
  "Wolf",
  "Falcon",
  "Lion",
  "Panther",
  "Raven",
  "Hawk",
  "Bear",
  "Fox",
  "Owl",
  "Shark",
  "Dolphin",
  "Penguin",
  "Koala",
  "Panda",
  "Otter",
  "Rabbit",
  "Squirrel",
  "Raccoon",
  "Beaver",
];

/**
 * Generate a random fun organization name
 * Example: "Magic Unicorn", "Cosmic Dragon"
 */
function generateRandomOrgName(): string {
  const adjective = ADJECTIVES[Math.floor(Math.random() * ADJECTIVES.length)];
  const noun = NOUNS[Math.floor(Math.random() * NOUNS.length)];
  return `${adjective} ${noun}`;
}

/**
 * Generate slug from name
 * Example: "Magic Unicorn" → "magic-unicorn"
 */
function nameToSlug(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

// TODO: Backend - Database schema changes needed:
// 1. Add `allowed_email_domains` to organizations table:
//    ALTER TABLE teams ADD COLUMN allowed_email_domains TEXT[] DEFAULT '{}';
//    This will store domains like ['@company.com', '@subsidiary.com']
//
// 2. Add index for domain searches:
//    CREATE INDEX idx_teams_allowed_domains ON teams USING GIN (allowed_email_domains);

// TODO: Backend - API endpoints needed:
// 1. GET /api/user/joinable-organizations
//    - Extract user email domain from authenticated user
//    - Query organizations where user's @domain is in allowed_email_domains
//    - Return: { organizations: Array<{ id, name, slug, avatar_url, member_count, sample_members }> }
//
// 2. POST /api/organizations/{org_slug}/join
//    - Verify user's email domain is in org's allowed_email_domains
//    - Create member record for user
//    - Return: { success: boolean, org: { id, name, slug } }

interface JoinableOrg {
  id: number;
  name: string;
  slug: string;
  avatar_url: string;
  member_count: number;
  sample_members: Array<{
    id: string;
    avatar_url: string;
  }>;
}

// TODO: Replace with actual SDK hook once backend is ready
// Example: const { data: joinableOrgs } = useJoinableOrganizations();
const MOCK_JOINABLE_ORGS: JoinableOrg[] = [
  {
    id: 1,
    name: "With my team",
    slug: "my-team",
    avatar_url: "",
    member_count: 24,
    sample_members: [
      { id: "1", avatar_url: "" },
      { id: "2", avatar_url: "" },
      { id: "3", avatar_url: "" },
      { id: "4", avatar_url: "" },
    ],
  },
  {
    id: 2,
    name: "On my own",
    slug: "my-own",
    avatar_url: "",
    member_count: 24,
    sample_members: [
      { id: "5", avatar_url: "" },
      { id: "6", avatar_url: "" },
      { id: "7", avatar_url: "" },
      { id: "8", avatar_url: "" },
    ],
  },
];

function OrganizationCard({
  org,
  onJoin,
}: {
  org: JoinableOrg;
  onJoin: (orgSlug: string) => void;
}) {
  return (
    <div className="border border-border rounded-lg p-3 flex items-center gap-3 w-full">
      {/* Org Avatar */}
      <Avatar
        url={org.avatar_url}
        fallback={org.slug}
        size="lg"
        objectFit="contain"
        className="shrink-0"
      />

      {/* Org Info */}
      <div className="flex flex-col gap-1 flex-1 min-w-0">
        <p className="text-sm font-medium text-foreground truncate">
          {org.name}
        </p>
        <div className="flex items-center gap-2">
          {/* Member Avatars */}
          <div className="flex items-center -space-x-1">
            {org.sample_members.slice(0, 4).map((member) => (
              <Avatar
                key={member.id}
                url={member.avatar_url}
                fallback="?"
                size="xs"
                className="border border-border"
              />
            ))}
          </div>
          <span className="text-xs text-foreground">
            {org.member_count} members
          </span>
        </div>
      </div>

      {/* Join Button */}
      <Button size="sm" className="shrink-0" onClick={() => onJoin(org.slug)}>
        Join
      </Button>
    </div>
  );
}

function JoinOrganizationsContent() {
  const navigate = useNavigate();
  const [isJoining, setIsJoining] = useState(false);
  const createTeam = useCreateTeam();

  // TODO: Replace with actual API call
  const joinableOrgs = MOCK_JOINABLE_ORGS;

  async function handleJoinOrg(orgSlug: string) {
    setIsJoining(true);
    try {
      // TODO: Backend API call needed
      // POST /api/organizations/{orgSlug}/join
      // Body: none (user is determined from auth session)
      // Response: { success: boolean, org: { id, name, slug } }

      console.log("Joining org:", orgSlug);

      // After successful join, redirect to that org's home
      // TODO: After backend is ready, use the returned org data
      navigate(`/${orgSlug}`);
    } catch (error) {
      console.error("Failed to join organization:", error);
      // TODO: Show error toast
    } finally {
      setIsJoining(false);
    }
  }

  async function handleCreateNew() {
    setIsJoining(true);
    try {
      // Generate random fun name
      const randomName = generateRandomOrgName();
      const slug = nameToSlug(randomName);

      // Create org immediately with random name
      const team = await createTeam.mutateAsync({
        name: randomName,
        slug,
      });

      // Navigate to the org with setup flag
      navigate(`/${team.slug}?setup=true`);
    } catch (error) {
      console.error("Failed to create organization:", error);
      // Show error message
      if (error instanceof Error) {
        alert(`Failed to create organization: ${error.message}`);
      }
    } finally {
      setIsJoining(false);
    }
  }

  // If no joinable orgs, skip this step entirely
  if (joinableOrgs.length === 0) {
    // TODO: After backend is ready, auto-redirect if no orgs available
    // For now, show the create option
  }

  return (
    <SplitScreenLayout>
      {/* Logo */}
      <div className="h-[26px] w-[62px]">
        <img
          src="/img/deco-logo.svg"
          alt="deco"
          className="w-full h-full object-contain"
        />
      </div>

      {/* Main Content */}
      <div className="flex flex-col gap-10 flex-1">
        {/* Header */}
        <div className="flex flex-col gap-2">
          <h1 className="text-2xl font-medium text-foreground">
            You have access to these admins
          </h1>
          <p className="text-base text-muted-foreground">
            Looks like there are existing admins connected to your email.
          </p>
        </div>

        {/* Organization List */}
        <div className="flex flex-col gap-5 w-full">
          {joinableOrgs.map((org) => (
            <OrganizationCard key={org.id} org={org} onJoin={handleJoinOrg} />
          ))}

          {/* Create New Button */}
          <Button
            variant="default"
            className="w-full"
            onClick={handleCreateNew}
            disabled={isJoining}
          >
            <Icon name="add" size={16} />
            Create new admin
          </Button>
        </div>
      </div>

      {/* Empty footer space for layout balance */}
      <div />
    </SplitScreenLayout>
  );
}

export function JoinOrganizations() {
  return (
    <QueryClientProvider client={queryClient}>
      <JoinOrganizationsContent />
    </QueryClientProvider>
  );
}

export default JoinOrganizations;
