# Landing Page Generation - Agent Orchestration

Generate 5 landing page variants for InfiniteStories using a collaborative agent team.

## Agent Team

Load these agent definitions to understand each role:

| Agent | Definition | Responsibility |
|-------|------------|----------------|
| Manager | `@.claude/commands/landing-page/agents/manager.md` | Orchestration & synthesis |
| Copywriter | `@.claude/commands/landing-page/agents/copywriter.md` | Headlines, CTAs, copy |
| Storyteller | `@.claude/commands/landing-page/agents/storyteller.md` | Narratives, emotions |
| Marketer | `@.claude/commands/landing-page/agents/marketer.md` | Conversion, positioning |
| SEO Expert | `@.claude/commands/landing-page/agents/seo-expert.md` | Keywords, meta, schema |

## Orchestration Workflow

Execute these phases in order:

### Phase 1: Initialize
1. Read all agent definition files listed above
2. Create output directory: `landing-pages/`
3. Load product information from this file

### Phase 2: Parallel Agent Contributions
Use the **Task tool** to launch 4 agents IN PARALLEL (single message, multiple Task calls):

```
Task 1: Copywriter Agent
- subagent_type: "general-purpose"
- prompt: "You are the Copywriter Agent. [Include full copywriter.md content].
  Create headlines, CTAs, and copy for all 5 landing page variants:
  1. Emotional (parent-child bond)
  2. Features (tech capabilities)
  3. Problem-Solution (pain → relief)
  4. Storytelling (narrative journey)
  5. Social Proof (trust-first)

  Output structured content for each variant's: Hero, Features, How It Works, CTA sections."

Task 2: Storyteller Agent
- subagent_type: "general-purpose"
- prompt: "You are the Storyteller Agent. [Include full storyteller.md content].
  Create emotional narratives for all 5 landing page variants.

  Output structured content for each variant's: Problem, Solution, testimonial stories."

Task 3: Marketer Agent
- subagent_type: "general-purpose"
- prompt: "You are the Marketer Agent. [Include full marketer.md content].
  Create conversion strategy for all 5 landing page variants.

  Output: Page structure, CTA placement, trust signals, A/B test suggestions for each."

Task 4: SEO Expert Agent
- subagent_type: "general-purpose"
- prompt: "You are the SEO Expert Agent. [Include full seo-expert.md content].
  Create SEO strategy for all 5 landing page variants.

  Output: Meta titles, descriptions, keywords, header structure, schema markup for each."
```

### Phase 3: Synthesis (Manager Role)
After all agents complete, synthesize their outputs:

1. Combine contributions into unified landing pages
2. Ensure brand voice consistency
3. Resolve any conflicts between agent suggestions
4. Apply the variant theme throughout each page

### Phase 4: Generate Output Files
Create these files in `landing-pages/`:

```
landing-pages/
├── README.md                    # Comparison of all variants
├── variant-1-emotional.md       # Parent-child bond focus
├── variant-2-features.md        # Technical features focus
├── variant-3-problem-solution.md # Pain → solution focus
├── variant-4-storytelling.md    # Narrative approach
└── variant-5-social-proof.md    # Trust & testimonials focus
```

## Product Information

**App**: InfiniteStories - AI-powered personalized bedtime stories

**Core Value Prop**: Your child becomes the hero of magical AI-generated bedtime adventures

**Key Features**:
- Custom hero characters with child's traits/appearance
- AI-generated stories (GPT-4o) featuring YOUR child
- High-quality audio narration (multiple voices, 5 languages)
- Beautiful AI illustrations synced to audio
- Custom story events (birthdays, milestones)
- Reading journey statistics
- Child-safe content filtering

**Target Audience**: Parents of children ages 2-10

**Pain Points**:
- Exhausted parents running out of story ideas
- Generic stories that don't engage children
- Bedtime battles and resistance
- Lack of creative energy after long days
- Children wanting repetitive stories

**Emotional Benefits**:
- Transform bedtimes into magical moments
- Create lasting personalized memories
- Make children feel special and heroic
- Spark imagination and reading love
- Quality bonding without creative pressure

## Landing Page Template

Each variant must include:

```markdown
# [Variant Name]: [Tagline]

## Meta Information
- **Title Tag**: [60 chars max]
- **Meta Description**: [155 chars max]
- **Primary Keywords**: [list]
- **URL Slug**: [clean-url]

---

## Hero Section
### Headline
### Subheadline
### Primary CTA
### Supporting Elements

## Problem Section
### The Struggle
### Pain Points

## Solution Section
### The Answer
### Key Benefits

## Features Section
### Feature 1-6 with Benefits

## How It Works
### Step 1-3/4

## Social Proof Section
### Testimonials
### Stats/Trust Badges

## Pricing/CTA Section
### Offer
### Final CTA

## FAQ Section
### 4-6 Questions

## Footer CTA
### Last Reminder

---

## Design Notes
## A/B Testing Suggestions
```

## Quality Checklist

Before finalizing:
- [ ] Each variant has unique, differentiated headline
- [ ] Value prop clear within 5 seconds
- [ ] Emotional hooks match variant theme
- [ ] Benefits emphasized over features
- [ ] 3+ CTAs per page
- [ ] SEO meta complete
- [ ] Mobile-friendly copy
- [ ] Consistent brand voice
- [ ] README compares all variants

## Execution

Begin by reading all agent files, then launch the 4 specialist agents in parallel using the Task tool. After receiving their outputs, synthesize into final landing pages.
