import { useState } from "react";
import { useNavigate } from "react-router";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Button } from "@deco/ui/components/button.tsx";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@deco/ui/components/form.tsx";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@deco/ui/components/select.tsx";
import { SplitScreenLayout } from "../login/layout.tsx";

// TODO: Add to DB schema - create user_profile or user_metadata table with these fields:
// - user_id (FK to auth.users)
// - role (text)
// - company_size (text)
// - use_case (text)
// - onboarding_completed_at (timestamp)
// - created_at (timestamp)
// - updated_at (timestamp)

const ROLES = [
  { value: "engineering", label: "Engineering" },
  { value: "product", label: "Product" },
  { value: "marketing", label: "Marketing" },
  { value: "design", label: "Design" },
  { value: "operations", label: "Operations" },
  { value: "sales", label: "Sales" },
  { value: "founder", label: "Founder/Executive" },
  { value: "other", label: "Other" },
];

const COMPANY_SIZES = [
  { value: "1", label: "Just me" },
  { value: "2-25", label: "2-25" },
  { value: "26-100", label: "26-100" },
  { value: "101-500", label: "101-500" },
  { value: "501-1000", label: "501-1000" },
  { value: "1001+", label: "1001+" },
];

const USE_CASES = [
  { value: "internal-apps", label: "Make internal apps" },
  { value: "manage-mcps", label: "Manage MCPs" },
  { value: "ai-saas", label: "Create AI SaaS" },
];

const schema = z.object({
  role: z.string().min(1, "Please select your role"),
  companySize: z.string().min(1, "Please select company size"),
  useCase: z.string().min(1, "Please tell us what you're using deco for"),
});

type FormData = z.infer<typeof schema>;

export function OnboardingQuestions() {
  const navigate = useNavigate();
  const [isSubmitting, setIsSubmitting] = useState(false);

  const form = useForm<FormData>({
    resolver: zodResolver(schema),
    defaultValues: {
      role: "",
      companySize: "",
      useCase: "",
    },
  });

  async function onSubmit(data: FormData) {
    setIsSubmitting(true);
    try {
      // TODO: Backend API call needed
      // POST /api/user/onboarding
      // Body: { role: data.role, company_size: data.companySize, use_case: data.useCase }
      // This should:
      // 1. Save user profile data to user_profile table
      // 2. Mark onboarding_completed_at = NOW()
      // 3. Track analytics event for onboarding completion

      console.log("Onboarding data:", data);

      // After saving profile, check for joinable organizations
      // TODO: After backend is ready, check if user has joinable orgs
      // If yes, navigate to /onboarding/join
      // If no, navigate to / (home) where they can create an org
      navigate("/onboarding/join");
    } catch (error) {
      console.error("Failed to save onboarding data:", error);
      // TODO: Show error toast
    } finally {
      setIsSubmitting(false);
    }
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
            Tell us more about you
          </h1>
          <p className="text-base text-muted-foreground">
            We just need a few more details to complete your profile.
          </p>
        </div>

        {/* Form */}
        <Form {...form}>
          <form
            onSubmit={form.handleSubmit(onSubmit)}
            className="flex flex-col gap-6 w-full"
          >
            {/* Role */}
            <FormField
              control={form.control}
              name="role"
              render={({ field }) => (
                <FormItem className="w-full">
                  <FormLabel>What is your role?</FormLabel>
                  <Select
                    onValueChange={field.onChange}
                    defaultValue={field.value}
                  >
                    <FormControl>
                      <SelectTrigger className="w-full">
                        <SelectValue placeholder="Select your role" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {ROLES.map((role) => (
                        <SelectItem key={role.value} value={role.value}>
                          {role.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />

            {/* Company Size */}
            <FormField
              control={form.control}
              name="companySize"
              render={({ field }) => (
                <FormItem className="w-full">
                  <FormLabel>What&apos;s the size of your company?</FormLabel>
                  <Select
                    onValueChange={field.onChange}
                    defaultValue={field.value}
                  >
                    <FormControl>
                      <SelectTrigger className="w-full">
                        <SelectValue placeholder="Select company size" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {COMPANY_SIZES.map((size) => (
                        <SelectItem key={size.value} value={size.value}>
                          {size.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />

            {/* Use Case */}
            <FormField
              control={form.control}
              name="useCase"
              render={({ field }) => (
                <FormItem className="w-full">
                  <FormLabel>What are you using deco for?</FormLabel>
                  <Select
                    onValueChange={field.onChange}
                    defaultValue={field.value}
                  >
                    <FormControl>
                      <SelectTrigger className="w-full">
                        <SelectValue placeholder="Select your use case" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {USE_CASES.map((useCase) => (
                        <SelectItem key={useCase.value} value={useCase.value}>
                          {useCase.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />
          </form>
        </Form>
      </div>

      {/* Continue Button */}
      <div className="flex justify-end w-full">
        <Button
          type="submit"
          size="lg"
          disabled={isSubmitting}
          onClick={form.handleSubmit(onSubmit)}
        >
          Continue
        </Button>
      </div>
    </SplitScreenLayout>
  );
}

export default OnboardingQuestions;
