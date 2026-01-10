"use client"

import type { ParsedBrief } from "@/lib/api-client"

type ParsedBriefViewProps = {
  parsedData: ParsedBrief
}

export function ParsedBriefView({ parsedData }: ParsedBriefViewProps) {
  return (
    <div className="space-y-6">
      {/* Hook */}
      <section>
        <h3 className="text-sm font-medium text-muted-foreground mb-2">Hook</h3>
        <p className="text-lg font-semibold">{parsedData.hook}</p>
      </section>

      {/* Persona */}
      <section>
        <h3 className="text-sm font-medium text-muted-foreground mb-2">
          Target Persona
        </h3>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <span className="text-xs text-muted-foreground">Type</span>
            <p className="font-medium capitalize">{parsedData.persona.type}</p>
          </div>
          <div>
            <span className="text-xs text-muted-foreground">Age</span>
            <p className="font-medium">{parsedData.persona.age}</p>
          </div>
          <div>
            <span className="text-xs text-muted-foreground">Demographic</span>
            <p className="font-medium capitalize">
              {parsedData.persona.demographic}
            </p>
          </div>
          <div>
            <span className="text-xs text-muted-foreground">Tone</span>
            <p className="font-medium capitalize">{parsedData.persona.tone}</p>
          </div>
        </div>
      </section>

      {/* Emotion */}
      <section>
        <h3 className="text-sm font-medium text-muted-foreground mb-2">
          Emotion
        </h3>
        <span className="px-3 py-1 bg-primary/10 text-primary rounded-full text-sm capitalize">
          {parsedData.emotion}
        </span>
      </section>

      {/* B-Roll Tags */}
      <section>
        <h3 className="text-sm font-medium text-muted-foreground mb-2">
          B-Roll Scenes
        </h3>
        <div className="flex flex-wrap gap-2">
          {parsedData.brollTags.map((tag, i) => (
            <span
              key={i}
              className="px-3 py-1 bg-muted rounded-full text-sm"
            >
              {tag}
            </span>
          ))}
        </div>
      </section>

      {/* Testimonial Points */}
      <section>
        <h3 className="text-sm font-medium text-muted-foreground mb-2">
          Key Messages
        </h3>
        <ul className="space-y-2">
          {parsedData.testimonialPoints.map((point, i) => (
            <li key={i} className="flex items-start gap-2">
              <span className="text-primary">•</span>
              <span>{point}</span>
            </li>
          ))}
        </ul>
      </section>
    </div>
  )
}
