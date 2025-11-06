import { useEffect, useMemo, useRef, useState } from "react";
import { useSearchParams } from "react-router";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import {
  Dialog,
  DialogPortal,
  DialogOverlay,
} from "@deco/ui/components/dialog.tsx";
import * as DialogPrimitive from "@radix-ui/react-dialog";
import { Button } from "@deco/ui/components/button.tsx";
import { Input } from "@deco/ui/components/input.tsx";
import { Checkbox } from "@deco/ui/components/checkbox.tsx";
import { Avatar } from "../common/avatar";
import { useUpdateTeam, useWriteFile, Locator } from "@deco/sdk";
import { Hosts } from "@deco/sdk/hosts";
import { toast } from "@deco/ui/components/sonner.tsx";
import { useUser } from "../../hooks/use-user.ts";

function extractDomain(email: string): string {
  const parts = email.split("@");
  return parts.length === 2 ? parts[1] : "";
}

function domainToCompanyName(domain: string): string {
  if (!domain) return "";
  const name = domain.split(".")[0]; // Get first part before TLD
  return name.charAt(0).toUpperCase() + name.slice(1);
}

function nameToSlug(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

function getLogoUrl(domain: string): string {
  if (!domain) return "";
  return `https://www.google.com/s2/favicons?domain=${domain}&sz=256`;
}

const schema = z.object({
  companyUrl: z.string().min(1, "Company URL is required"),
  name: z.string().min(1, "Organization name is required"),
  allowDomainJoin: z.boolean(),
});

type FormData = z.infer<typeof schema>;

interface SetupOrgDialogProps {
  orgSlug: string;
  currentOrgName: string;
  orgId: number;
}

export function SetupOrgDialog({
  orgSlug,
  currentOrgName,
  orgId,
}: SetupOrgDialogProps) {
  const [searchParams, setSearchParams] = useSearchParams();
  const updateTeam = useUpdateTeam();
  const writeFile = useWriteFile();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [logoUrl, setLogoUrl] = useState("");
  const [uploadedLogoPath, setUploadedLogoPath] = useState("");
  const [isUploading, setIsUploading] = useState(false);
  const user = useUser();

  const isOpen = searchParams.get("setup") === "true";

  const locator = Locator.from({ org: orgSlug, project: "default" });

  // Extract domain from user's email
  const userEmail = user?.email || "";
  const userDomain = extractDomain(userEmail);
  const suggestedCompanyName = domainToCompanyName(userDomain);

  const form = useForm<FormData>({
    resolver: zodResolver(schema),
    defaultValues: {
      companyUrl: userDomain,
      name: suggestedCompanyName || currentOrgName,
      allowDomainJoin: true,
    },
  });

  const companyUrl = form.watch("companyUrl");
  const orgName = form.watch("name");

  // Generate slug from org name
  const slug = useMemo(() => nameToSlug(orgName), [orgName]);

  // Update organization name and logo when company URL changes
  useEffect(() => {
    if (companyUrl) {
      // Update logo
      if (!uploadedLogoPath) {
        const url = getLogoUrl(companyUrl);
        setLogoUrl(url);
      }

      // Update organization name suggestion
      const suggestedName = domainToCompanyName(companyUrl);
      if (suggestedName) {
        form.setValue("name", suggestedName);
      }
    }
  }, [companyUrl, uploadedLogoPath, form]);

  async function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;

    if (!file.type.startsWith("image/")) {
      toast.error("Please select an image file");
      return;
    }

    try {
      setIsUploading(true);

      // Generate filename
      const extension = file.name.split(".").pop() || "png";
      const filename = `org-logo-${crypto.randomUUID()}.${extension}`;
      const path = `uploads/${filename}`;

      // Upload file
      const buffer = await file.arrayBuffer();
      await writeFile.mutateAsync({
        path,
        contentType: file.type,
        content: new Uint8Array(buffer),
      });

      // Set uploaded logo
      const url = `https://${Hosts.API_LEGACY}/files/${locator}/${path}`;
      setUploadedLogoPath(path);
      setLogoUrl(url);

      toast.success("Logo uploaded successfully");
    } catch (error) {
      console.error("Failed to upload logo:", error);
      toast.error("Failed to upload logo");
    } finally {
      setIsUploading(false);
    }
  }

  function handleClose() {
    // Remove setup query param
    searchParams.delete("setup");
    setSearchParams(searchParams);
  }

  async function onSubmit(data: FormData) {
    try {
      // Update the organization name
      // TODO: After backend supports avatar_url field in TEAMS_UPDATE, update with:
      // - avatar_url: uploadedLogoPath or logoUrl
      // TODO: After backend supports allowed_email_domains, update with:
      // - allowed_email_domains: data.allowDomainJoin ? [`@${data.companyUrl}`] : []

      await updateTeam.mutateAsync({
        id: orgId,
        data: {
          name: data.name,
        },
      });

      toast.success("Organization updated successfully");

      // Close the dialog
      handleClose();
    } catch (error) {
      console.error("Failed to update organization:", error);
      toast.error(
        error instanceof Error
          ? `Failed to update: ${error.message}`
          : "Failed to update organization",
      );
    }
  }

  return (
    <Dialog open={isOpen}>
      {/* Hidden file input */}
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        onChange={handleFileChange}
        className="hidden"
      />

      {/* Custom black blur backdrop */}
      <DialogPortal>
        <DialogOverlay className="bg-black/20 backdrop-blur-[2px] p-4 sm:p-6 md:p-12 lg:p-18" />
        <DialogPrimitive.Content className="w-[calc(100vw-2rem)] sm:w-[calc(100vw-3rem)] md:w-[calc(100vw-6rem)] lg:w-[calc(100vw-9rem)] max-w-[1280px] h-[calc(100vh-2rem)] sm:h-[calc(100vh-3rem)] md:h-[calc(100vh-6rem)] lg:h-[calc(100vh-9rem)] p-0 gap-0 overflow-hidden fixed top-[50%] left-[50%] z-50 translate-x-[-50%] translate-y-[-50%] rounded-2xl border border-white/25 shadow-lg data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95 duration-200">
          <div className="flex flex-col lg:flex-row h-full">
            {/* Left panel - Decorative image */}
            <div
              className="hidden lg:block relative lg:w-1/2 bg-brand-green-light"
              style={{
                backgroundImage: `url('https://assets.decocache.com/decocms/5fcc2d02-b923-4458-a3ad-7c11a853cf47/product-onboarding.png')`,
                backgroundSize: "cover",
                backgroundPosition: "top",
              }}
            ></div>

            {/* Right panel - Form content */}
            <div className="w-full lg:w-1/2 overflow-y-auto px-6 py-8 sm:px-10 sm:py-12 md:px-16 md:py-14 bg-background">
              <div className="flex flex-col h-full gap-12">
                <div>
                  <h2 className="text-2xl font-medium">Let's get started</h2>
                  <p className="text-base text-muted-foreground mt-2">
                    Set up your admin for scalable AI apps
                  </p>
                </div>

                <form
                  onSubmit={form.handleSubmit(onSubmit)}
                  className="flex flex-col gap-6 flex-1"
                >
                  {/* Company URL */}
                  <div className="flex flex-col gap-2.5">
                    <label className="text-sm font-medium text-foreground">
                      Company URL
                    </label>
                    <div className="relative">
                      <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm text-muted-foreground">
                        https://
                      </span>
                      <Input
                        {...form.register("companyUrl")}
                        className="pl-[70px]"
                        placeholder="acme.com"
                      />
                    </div>
                    {form.formState.errors.companyUrl && (
                      <p className="text-sm text-destructive">
                        {form.formState.errors.companyUrl.message}
                      </p>
                    )}
                  </div>

                  {/* Organization Name */}
                  <div className="flex flex-col gap-2.5">
                    <label className="text-sm font-medium text-foreground">
                      Organization name
                    </label>
                    <Input {...form.register("name")} placeholder="Acme Inc" />
                    <p className="text-sm text-muted-foreground">
                      admin.decocms.com/{slug}
                    </p>
                    {form.formState.errors.name && (
                      <p className="text-sm text-destructive">
                        {form.formState.errors.name.message}
                      </p>
                    )}
                  </div>

                  {/* Logo Preview */}
                  <div className="flex items-start gap-2.5">
                    <div className="relative shrink-0">
                      <Avatar
                        url={logoUrl}
                        fallback={form.watch("name")}
                        size="3xl"
                        objectFit="contain"
                      />
                    </div>

                    <div className="flex flex-col gap-2.5">
                      <Button
                        type="button"
                        variant="outline"
                        size="sm"
                        disabled={isUploading}
                        onClick={() => fileInputRef.current?.click()}
                      >
                        {isUploading ? "Uploading..." : "Upload Image"}
                      </Button>
                      <p className="text-sm text-muted-foreground px-2">
                        Recommended: 1080x1080px
                      </p>
                      {uploadedLogoPath && (
                        <p className="text-xs text-green-600 px-2">
                          ✓ Custom logo uploaded
                        </p>
                      )}
                      {!uploadedLogoPath && logoUrl && (
                        <p className="text-xs text-muted-foreground px-2">
                          Favicon auto-fetched
                        </p>
                      )}
                    </div>
                  </div>

                  {/* Allow Domain Join */}
                  <div className="border border-border rounded-lg p-4 flex items-center gap-2">
                    <Checkbox
                      id="allowDomainJoin"
                      checked={form.watch("allowDomainJoin")}
                      onCheckedChange={(checked) =>
                        form.setValue("allowDomainJoin", checked === true)
                      }
                    />
                    <label
                      htmlFor="allowDomainJoin"
                      className="text-sm text-foreground cursor-pointer"
                    >
                      Allow anyone with{" "}
                      <span className="text-amber-600">@{companyUrl}</span> to
                      join
                    </label>
                  </div>
                </form>

                {/* Buttons - Fixed at bottom */}
                <div className="flex justify-end">
                  <Button
                    onClick={form.handleSubmit(onSubmit)}
                    disabled={updateTeam.isPending}
                  >
                    {updateTeam.isPending ? "Saving..." : "Save"}
                  </Button>
                </div>
              </div>
            </div>
          </div>
        </DialogPrimitive.Content>
      </DialogPortal>
    </Dialog>
  );
}
