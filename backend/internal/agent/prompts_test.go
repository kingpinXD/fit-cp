package agent

import (
	"strings"
	"testing"
)

// Both prompts are baked in as constants so OpenAI's prompt cache can hit on
// the prefix. These tests guard against accidental edits — if you change a
// prompt, update the expected prefix here in the same commit so the change is
// explicit in code review.

func TestChatSystemPromptStable(t *testing.T) {
	if len(chatSystemPrompt) == 0 {
		t.Fatal("chatSystemPrompt is empty")
	}
	const wantPrefix = "You are a fitness assistant"
	if !strings.HasPrefix(chatSystemPrompt, wantPrefix) {
		t.Errorf("chat prompt prefix changed; want %q, got %q", wantPrefix, chatSystemPrompt[:len(wantPrefix)])
	}
}

func TestCoachSystemPromptCoversKeyConcepts(t *testing.T) {
	if len(coachSystemPrompt) == 0 {
		t.Fatal("coachSystemPrompt is empty")
	}
	for _, want := range []string{
		"Coach",
		"propose_programme",
		"search_exercises",
		"Days per week",
		"Experience",
		"12 weeks",
		"3 mesocycle blocks",
		"Push",
		"Upper",
		"Block 1",
		"Full Body every day",
		"Push/Pull/Legs",
		"Upper/Lower",
		"Cap RPE at 7",
		"Skip exercises that load the injured area",
		"Between blocks, you MAY swap",
	} {
		if !strings.Contains(coachSystemPrompt, want) {
			t.Errorf("coach prompt missing %q", want)
		}
	}
	// The Coach must not teach the model to use placeholder day labels — the
	// validator rejects them, so emitting one wastes a round-trip.
	for _, banned := range []string{"Day 1", "Day 2", "Workout 1", "Session 1"} {
		if strings.Contains(coachSystemPrompt, banned) {
			t.Errorf("coach prompt should not contain placeholder example %q", banned)
		}
	}
}
