export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.17"
  }
  public: {
    Tables: {
      areas: {
        Row: {
          created_at: string
          description: string
          id: string
          is_active: boolean
          name: string
          slug: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string
          id?: string
          is_active?: boolean
          name: string
          slug: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string
          id?: string
          is_active?: boolean
          name?: string
          slug?: string
          updated_at?: string
        }
        Relationships: []
      }
      daily_queue_members: {
        Row: {
          created_at: string
          flashcard_id: string
          id: string
          origin: string
          position: number
          priority: number
          queue_id: string
        }
        Insert: {
          created_at?: string
          flashcard_id: string
          id?: string
          origin: string
          position: number
          priority: number
          queue_id: string
        }
        Update: {
          created_at?: string
          flashcard_id?: string
          id?: string
          origin?: string
          position?: number
          priority?: number
          queue_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "daily_queue_members_flashcard_id_fkey"
            columns: ["flashcard_id"]
            isOneToOne: false
            referencedRelation: "flashcards"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "daily_queue_members_queue_id_fkey"
            columns: ["queue_id"]
            isOneToOne: false
            referencedRelation: "daily_study_queues"
            referencedColumns: ["id"]
          },
        ]
      }
      daily_study_attempts: {
        Row: {
          card_version_seen: number | null
          committed_event_id: string | null
          created_at: string
          flashcard_id: string
          id: string
          operation_id: string
          prepared_at: string | null
          queue_id: string
          revealed: boolean
          state_revision_expected: number | null
        }
        Insert: {
          card_version_seen?: number | null
          committed_event_id?: string | null
          created_at?: string
          flashcard_id: string
          id?: string
          operation_id?: string
          prepared_at?: string | null
          queue_id: string
          revealed?: boolean
          state_revision_expected?: number | null
        }
        Update: {
          card_version_seen?: number | null
          committed_event_id?: string | null
          created_at?: string
          flashcard_id?: string
          id?: string
          operation_id?: string
          prepared_at?: string | null
          queue_id?: string
          revealed?: boolean
          state_revision_expected?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "daily_study_attempts_flashcard_id_card_version_seen_fkey"
            columns: ["flashcard_id", "card_version_seen"]
            isOneToOne: false
            referencedRelation: "flashcard_versions"
            referencedColumns: ["flashcard_id", "version"]
          },
          {
            foreignKeyName: "daily_study_attempts_flashcard_id_fkey"
            columns: ["flashcard_id"]
            isOneToOne: false
            referencedRelation: "flashcards"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "daily_study_attempts_queue_id_fkey"
            columns: ["queue_id"]
            isOneToOne: false
            referencedRelation: "daily_study_queues"
            referencedColumns: ["id"]
          },
        ]
      }
      daily_study_queues: {
        Row: {
          created_at: string
          day: string
          id: string
          policy_version: string
          section_id: string
          status: string
          timezone: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          day: string
          id?: string
          policy_version?: string
          section_id: string
          status?: string
          timezone?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          day?: string
          id?: string
          policy_version?: string
          section_id?: string
          status?: string
          timezone?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "daily_study_queues_section_id_fkey"
            columns: ["section_id"]
            isOneToOne: false
            referencedRelation: "sections"
            referencedColumns: ["id"]
          },
        ]
      }
      editorial_audit_log: {
        Row: {
          action: string
          actor_id: string | null
          created_at: string
          entity_id: string
          entity_type: string
          id: string
          new_data: Json | null
          old_data: Json | null
        }
        Insert: {
          action: string
          actor_id?: string | null
          created_at?: string
          entity_id: string
          entity_type: string
          id?: string
          new_data?: Json | null
          old_data?: Json | null
        }
        Update: {
          action?: string
          actor_id?: string | null
          created_at?: string
          entity_id?: string
          entity_type?: string
          id?: string
          new_data?: Json | null
          old_data?: Json | null
        }
        Relationships: []
      }
      editorial_import_rows: {
        Row: {
          code: string | null
          flashcard_id: string | null
          import_id: string
          line: number
          message: string
          operation: string
          payload: Json
          status: string
          updated_at: string
        }
        Insert: {
          code?: string | null
          flashcard_id?: string | null
          import_id: string
          line: number
          message?: string
          operation: string
          payload: Json
          status?: string
          updated_at?: string
        }
        Update: {
          code?: string | null
          flashcard_id?: string | null
          import_id?: string
          line?: number
          message?: string
          operation?: string
          payload?: Json
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "editorial_import_rows_flashcard_id_fkey"
            columns: ["flashcard_id"]
            isOneToOne: false
            referencedRelation: "flashcards"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "editorial_import_rows_import_id_fkey"
            columns: ["import_id"]
            isOneToOne: false
            referencedRelation: "editorial_imports"
            referencedColumns: ["id"]
          },
        ]
      }
      editorial_imports: {
        Row: {
          created_at: string
          filename: string
          fingerprint: string
          id: string
          mode: string
          status: string
          total_rows: number
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          filename: string
          fingerprint: string
          id?: string
          mode: string
          status?: string
          total_rows: number
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          filename?: string
          fingerprint?: string
          id?: string
          mode?: string
          status?: string
          total_rows?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      flashcard_media: {
        Row: {
          alt_text: string
          caption: string
          created_at: string
          created_by: string
          display_order: number
          flashcard_id: string
          id: string
          is_active: boolean
          placement: Database["public"]["Enums"]["media_placement"]
          storage_path: string
          type: Database["public"]["Enums"]["media_type"]
          updated_at: string
        }
        Insert: {
          alt_text?: string
          caption?: string
          created_at?: string
          created_by: string
          display_order?: number
          flashcard_id: string
          id?: string
          is_active?: boolean
          placement: Database["public"]["Enums"]["media_placement"]
          storage_path: string
          type: Database["public"]["Enums"]["media_type"]
          updated_at?: string
        }
        Update: {
          alt_text?: string
          caption?: string
          created_at?: string
          created_by?: string
          display_order?: number
          flashcard_id?: string
          id?: string
          is_active?: boolean
          placement?: Database["public"]["Enums"]["media_placement"]
          storage_path?: string
          type?: Database["public"]["Enums"]["media_type"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "flashcard_media_flashcard_id_fkey"
            columns: ["flashcard_id"]
            isOneToOne: false
            referencedRelation: "flashcards"
            referencedColumns: ["id"]
          },
        ]
      }
      flashcard_media_versions: {
        Row: {
          alt_text: string
          caption: string
          card_version: number
          created_at: string
          display_order: number
          flashcard_id: string
          id: string
          is_active: boolean
          media_id: string
          placement: Database["public"]["Enums"]["media_placement"]
          storage_path: string
          type: Database["public"]["Enums"]["media_type"]
        }
        Insert: {
          alt_text?: string
          caption?: string
          card_version: number
          created_at?: string
          display_order: number
          flashcard_id: string
          id?: string
          is_active: boolean
          media_id: string
          placement: Database["public"]["Enums"]["media_placement"]
          storage_path: string
          type: Database["public"]["Enums"]["media_type"]
        }
        Update: {
          alt_text?: string
          caption?: string
          card_version?: number
          created_at?: string
          display_order?: number
          flashcard_id?: string
          id?: string
          is_active?: boolean
          media_id?: string
          placement?: Database["public"]["Enums"]["media_placement"]
          storage_path?: string
          type?: Database["public"]["Enums"]["media_type"]
        }
        Relationships: [
          {
            foreignKeyName: "flashcard_media_versions_flashcard_id_card_version_fkey"
            columns: ["flashcard_id", "card_version"]
            isOneToOne: false
            referencedRelation: "flashcard_versions"
            referencedColumns: ["flashcard_id", "version"]
          },
        ]
      }
      flashcard_sections: {
        Row: {
          created_at: string
          flashcard_id: string
          section_id: string
        }
        Insert: {
          created_at?: string
          flashcard_id: string
          section_id: string
        }
        Update: {
          created_at?: string
          flashcard_id?: string
          section_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "flashcard_sections_flashcard_id_fkey"
            columns: ["flashcard_id"]
            isOneToOne: false
            referencedRelation: "flashcards"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "flashcard_sections_section_id_fkey"
            columns: ["section_id"]
            isOneToOne: false
            referencedRelation: "sections"
            referencedColumns: ["id"]
          },
        ]
      }
      flashcard_tags: {
        Row: {
          created_at: string
          flashcard_id: string
          tag_id: string
        }
        Insert: {
          created_at?: string
          flashcard_id: string
          tag_id: string
        }
        Update: {
          created_at?: string
          flashcard_id?: string
          tag_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "flashcard_tags_flashcard_id_fkey"
            columns: ["flashcard_id"]
            isOneToOne: false
            referencedRelation: "flashcards"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "flashcard_tags_tag_id_fkey"
            columns: ["tag_id"]
            isOneToOne: false
            referencedRelation: "tags"
            referencedColumns: ["id"]
          },
        ]
      }
      flashcard_versions: {
        Row: {
          area_id: string
          change_summary: string | null
          changed_by: string
          code: string
          comment: Json
          created_at: string
          editorial_difficulty: string
          flashcard_id: string
          id: string
          question: string
          reference: string
          short_answer: string
          status: Database["public"]["Enums"]["flashcard_status"]
          subtopic_id: string | null
          topic_id: string
          version: number
        }
        Insert: {
          area_id: string
          change_summary?: string | null
          changed_by: string
          code: string
          comment: Json
          created_at?: string
          editorial_difficulty: string
          flashcard_id: string
          id?: string
          question: string
          reference?: string
          short_answer: string
          status: Database["public"]["Enums"]["flashcard_status"]
          subtopic_id?: string | null
          topic_id: string
          version: number
        }
        Update: {
          area_id?: string
          change_summary?: string | null
          changed_by?: string
          code?: string
          comment?: Json
          created_at?: string
          editorial_difficulty?: string
          flashcard_id?: string
          id?: string
          question?: string
          reference?: string
          short_answer?: string
          status?: Database["public"]["Enums"]["flashcard_status"]
          subtopic_id?: string | null
          topic_id?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "flashcard_versions_flashcard_id_fkey"
            columns: ["flashcard_id"]
            isOneToOne: false
            referencedRelation: "flashcards"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "flashcard_versions_subtopic_topic_fkey"
            columns: ["subtopic_id", "topic_id"]
            isOneToOne: false
            referencedRelation: "subtopics"
            referencedColumns: ["id", "topic_id"]
          },
          {
            foreignKeyName: "flashcard_versions_topic_area_fkey"
            columns: ["topic_id", "area_id"]
            isOneToOne: false
            referencedRelation: "topics"
            referencedColumns: ["id", "area_id"]
          },
        ]
      }
      flashcards: {
        Row: {
          code: string
          comment: Json
          created_at: string
          created_by: string
          editorial_difficulty: string
          id: string
          question: string
          reference: string
          short_answer: string
          status: Database["public"]["Enums"]["flashcard_status"]
          subtopic_id: string | null
          topic_id: string
          updated_at: string
          updated_by: string
          version: number
        }
        Insert: {
          code?: string
          comment?: Json
          created_at?: string
          created_by: string
          editorial_difficulty?: string
          id?: string
          question: string
          reference?: string
          short_answer: string
          status?: Database["public"]["Enums"]["flashcard_status"]
          subtopic_id?: string | null
          topic_id: string
          updated_at?: string
          updated_by: string
          version?: number
        }
        Update: {
          code?: string
          comment?: Json
          created_at?: string
          created_by?: string
          editorial_difficulty?: string
          id?: string
          question?: string
          reference?: string
          short_answer?: string
          status?: Database["public"]["Enums"]["flashcard_status"]
          subtopic_id?: string | null
          topic_id?: string
          updated_at?: string
          updated_by?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "flashcards_subtopic_topic_fkey"
            columns: ["subtopic_id", "topic_id"]
            isOneToOne: false
            referencedRelation: "subtopics"
            referencedColumns: ["id", "topic_id"]
          },
          {
            foreignKeyName: "flashcards_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "topics"
            referencedColumns: ["id"]
          },
        ]
      }
      fsrs_configurations: {
        Row: {
          adapter_version: string
          algorithm_version: string
          created_at: string
          enable_fuzz: boolean
          enable_short_term: boolean
          id: string
          key: string
          learning_steps: Json
          maximum_interval: number
          package_name: string
          package_version: string
          relearning_steps: Json
          request_retention: number
          weights: Json
        }
        Insert: {
          adapter_version: string
          algorithm_version: string
          created_at?: string
          enable_fuzz: boolean
          enable_short_term: boolean
          id?: string
          key: string
          learning_steps: Json
          maximum_interval: number
          package_name: string
          package_version: string
          relearning_steps: Json
          request_retention: number
          weights: Json
        }
        Update: {
          adapter_version?: string
          algorithm_version?: string
          created_at?: string
          enable_fuzz?: boolean
          enable_short_term?: boolean
          id?: string
          key?: string
          learning_steps?: Json
          maximum_interval?: number
          package_name?: string
          package_version?: string
          relearning_steps?: Json
          request_retention?: number
          weights?: Json
        }
        Relationships: []
      }
      fsrs_initializations: {
        Row: {
          config_id: string
          created_at: string
          flashcard_id: string
          id: string
          origin: string
          reference_event_id: string | null
          user_id: string
        }
        Insert: {
          config_id: string
          created_at?: string
          flashcard_id: string
          id?: string
          origin: string
          reference_event_id?: string | null
          user_id: string
        }
        Update: {
          config_id?: string
          created_at?: string
          flashcard_id?: string
          id?: string
          origin?: string
          reference_event_id?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "fsrs_initializations_config_id_fkey"
            columns: ["config_id"]
            isOneToOne: false
            referencedRelation: "fsrs_configurations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fsrs_initializations_flashcard_id_fkey"
            columns: ["flashcard_id"]
            isOneToOne: false
            referencedRelation: "flashcards"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fsrs_initializations_reference_event_id_fkey"
            columns: ["reference_event_id"]
            isOneToOne: false
            referencedRelation: "learning_events"
            referencedColumns: ["id"]
          },
        ]
      }
      learning_events: {
        Row: {
          card_version_seen: number
          event_kind: string
          flashcard_id: string
          id: string
          learning_state_after: Database["public"]["Enums"]["learning_state"]
          learning_state_before: Database["public"]["Enums"]["learning_state"]
          operation_id: string
          rating: Database["public"]["Enums"]["review_rating"]
          reviewed_at: string
          session_id: string
          user_id: string
        }
        Insert: {
          card_version_seen: number
          event_kind?: string
          flashcard_id: string
          id?: string
          learning_state_after?: Database["public"]["Enums"]["learning_state"]
          learning_state_before: Database["public"]["Enums"]["learning_state"]
          operation_id: string
          rating: Database["public"]["Enums"]["review_rating"]
          reviewed_at?: string
          session_id: string
          user_id: string
        }
        Update: {
          card_version_seen?: number
          event_kind?: string
          flashcard_id?: string
          id?: string
          learning_state_after?: Database["public"]["Enums"]["learning_state"]
          learning_state_before?: Database["public"]["Enums"]["learning_state"]
          operation_id?: string
          rating?: Database["public"]["Enums"]["review_rating"]
          reviewed_at?: string
          session_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "learning_events_flashcard_id_card_version_seen_fkey"
            columns: ["flashcard_id", "card_version_seen"]
            isOneToOne: false
            referencedRelation: "flashcard_versions"
            referencedColumns: ["flashcard_id", "version"]
          },
          {
            foreignKeyName: "learning_events_flashcard_id_fkey"
            columns: ["flashcard_id"]
            isOneToOne: false
            referencedRelation: "flashcards"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "learning_events_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "study_sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_url: string | null
          created_at: string
          display_name: string
          id: string
          updated_at: string
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          display_name?: string
          id: string
          updated_at?: string
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          display_name?: string
          id?: string
          updated_at?: string
        }
        Relationships: []
      }
      review_events: {
        Row: {
          attempt_id: string | null
          card_version_seen: number
          config_id: string | null
          created_at: string
          flashcard_id: string
          fsrs_data: Json
          id: string
          learning_state_after: Database["public"]["Enums"]["learning_state"]
          learning_state_before:
            | Database["public"]["Enums"]["learning_state"]
            | null
          new_interval: number
          operation_id: string | null
          origin: string | null
          previous_interval: number
          rating: Database["public"]["Enums"]["review_rating"]
          reviewed_at: string
          scheduled_next_review: string
          state_revision_after: number | null
          state_revision_before: number | null
          user_id: string
        }
        Insert: {
          attempt_id?: string | null
          card_version_seen: number
          config_id?: string | null
          created_at?: string
          flashcard_id: string
          fsrs_data?: Json
          id?: string
          learning_state_after: Database["public"]["Enums"]["learning_state"]
          learning_state_before?:
            | Database["public"]["Enums"]["learning_state"]
            | null
          new_interval: number
          operation_id?: string | null
          origin?: string | null
          previous_interval?: number
          rating: Database["public"]["Enums"]["review_rating"]
          reviewed_at?: string
          scheduled_next_review: string
          state_revision_after?: number | null
          state_revision_before?: number | null
          user_id: string
        }
        Update: {
          attempt_id?: string | null
          card_version_seen?: number
          config_id?: string | null
          created_at?: string
          flashcard_id?: string
          fsrs_data?: Json
          id?: string
          learning_state_after?: Database["public"]["Enums"]["learning_state"]
          learning_state_before?:
            | Database["public"]["Enums"]["learning_state"]
            | null
          new_interval?: number
          operation_id?: string | null
          origin?: string | null
          previous_interval?: number
          rating?: Database["public"]["Enums"]["review_rating"]
          reviewed_at?: string
          scheduled_next_review?: string
          state_revision_after?: number | null
          state_revision_before?: number | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "review_events_attempt_id_fkey"
            columns: ["attempt_id"]
            isOneToOne: false
            referencedRelation: "daily_study_attempts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "review_events_config_id_fkey"
            columns: ["config_id"]
            isOneToOne: false
            referencedRelation: "fsrs_configurations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "review_events_flashcard_id_fkey"
            columns: ["flashcard_id"]
            isOneToOne: false
            referencedRelation: "flashcards"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "review_events_version_fkey"
            columns: ["flashcard_id", "card_version_seen"]
            isOneToOne: false
            referencedRelation: "flashcard_versions"
            referencedColumns: ["flashcard_id", "version"]
          },
        ]
      }
      sections: {
        Row: {
          created_at: string
          description: string
          id: string
          is_active: boolean
          name: string
          slug: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string
          id?: string
          is_active?: boolean
          name: string
          slug: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string
          id?: string
          is_active?: boolean
          name?: string
          slug?: string
          updated_at?: string
        }
        Relationships: []
      }
      study_session_items: {
        Row: {
          event_id: string | null
          flashcard_id: string
          id: string
          position: number
          revealed: boolean
          session_id: string
          skipped: boolean
          version_seen: number | null
        }
        Insert: {
          event_id?: string | null
          flashcard_id: string
          id?: string
          position: number
          revealed?: boolean
          session_id: string
          skipped?: boolean
          version_seen?: number | null
        }
        Update: {
          event_id?: string | null
          flashcard_id?: string
          id?: string
          position?: number
          revealed?: boolean
          session_id?: string
          skipped?: boolean
          version_seen?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "study_session_items_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "learning_events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "study_session_items_flashcard_id_fkey"
            columns: ["flashcard_id"]
            isOneToOne: false
            referencedRelation: "flashcards"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "study_session_items_flashcard_id_version_seen_fkey"
            columns: ["flashcard_id", "version_seen"]
            isOneToOne: false
            referencedRelation: "flashcard_versions"
            referencedColumns: ["flashcard_id", "version"]
          },
          {
            foreignKeyName: "study_session_items_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "study_sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      study_sessions: {
        Row: {
          created_at: string
          id: string
          section_id: string
          topic_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          section_id: string
          topic_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          section_id?: string
          topic_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "study_sessions_section_id_fkey"
            columns: ["section_id"]
            isOneToOne: false
            referencedRelation: "sections"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "study_sessions_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "topics"
            referencedColumns: ["id"]
          },
        ]
      }
      subtopics: {
        Row: {
          created_at: string
          description: string
          id: string
          is_active: boolean
          name: string
          slug: string
          topic_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string
          id?: string
          is_active?: boolean
          name: string
          slug: string
          topic_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string
          id?: string
          is_active?: boolean
          name?: string
          slug?: string
          topic_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "subtopics_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "topics"
            referencedColumns: ["id"]
          },
        ]
      }
      tags: {
        Row: {
          created_at: string
          id: string
          is_active: boolean
          name: string
          slug: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
          slug: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
          slug?: string
          updated_at?: string
        }
        Relationships: []
      }
      topics: {
        Row: {
          area_id: string
          created_at: string
          description: string
          id: string
          is_active: boolean
          name: string
          slug: string
          updated_at: string
        }
        Insert: {
          area_id: string
          created_at?: string
          description?: string
          id?: string
          is_active?: boolean
          name: string
          slug: string
          updated_at?: string
        }
        Update: {
          area_id?: string
          created_at?: string
          description?: string
          id?: string
          is_active?: boolean
          name?: string
          slug?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "topics_area_id_fkey"
            columns: ["area_id"]
            isOneToOne: false
            referencedRelation: "areas"
            referencedColumns: ["id"]
          },
        ]
      }
      user_flashcard_states: {
        Row: {
          created_at: string
          current_interval: number
          first_seen_at: string | null
          flashcard_id: string
          fsrs_config_id: string | null
          fsrs_data: Json
          fsrs_difficulty: number | null
          fsrs_initialization_id: string | null
          fsrs_last_computed_at: string | null
          fsrs_stability: number | null
          lapse_count: number
          last_reviewed_at: string | null
          learning_state: Database["public"]["Enums"]["learning_state"]
          next_review_at: string | null
          review_count: number
          scheduling_status: string | null
          state_revision: number
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          current_interval?: number
          first_seen_at?: string | null
          flashcard_id: string
          fsrs_config_id?: string | null
          fsrs_data?: Json
          fsrs_difficulty?: number | null
          fsrs_initialization_id?: string | null
          fsrs_last_computed_at?: string | null
          fsrs_stability?: number | null
          lapse_count?: number
          last_reviewed_at?: string | null
          learning_state?: Database["public"]["Enums"]["learning_state"]
          next_review_at?: string | null
          review_count?: number
          scheduling_status?: string | null
          state_revision?: number
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          current_interval?: number
          first_seen_at?: string | null
          flashcard_id?: string
          fsrs_config_id?: string | null
          fsrs_data?: Json
          fsrs_difficulty?: number | null
          fsrs_initialization_id?: string | null
          fsrs_last_computed_at?: string | null
          fsrs_stability?: number | null
          lapse_count?: number
          last_reviewed_at?: string | null
          learning_state?: Database["public"]["Enums"]["learning_state"]
          next_review_at?: string | null
          review_count?: number
          scheduling_status?: string | null
          state_revision?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_flashcard_states_flashcard_id_fkey"
            columns: ["flashcard_id"]
            isOneToOne: false
            referencedRelation: "flashcards"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_flashcard_states_fsrs_config_id_fkey"
            columns: ["fsrs_config_id"]
            isOneToOne: false
            referencedRelation: "fsrs_configurations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_flashcard_states_fsrs_initialization_id_fkey"
            columns: ["fsrs_initialization_id"]
            isOneToOne: false
            referencedRelation: "fsrs_initializations"
            referencedColumns: ["id"]
          },
        ]
      }
      user_roles: {
        Row: {
          created_at: string
          id: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
      user_study_preferences: {
        Row: {
          created_at: string
          daily_card_goal: number
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          daily_card_goal?: number
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          daily_card_goal?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      weekly_schedule_items: {
        Row: {
          created_at: string
          id: string
          release_at: string
          release_day: number
          release_order: number
          topic_id: string
          updated_at: string
          weekly_schedule_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          release_at: string
          release_day: number
          release_order: number
          topic_id: string
          updated_at?: string
          weekly_schedule_id: string
        }
        Update: {
          created_at?: string
          id?: string
          release_at?: string
          release_day?: number
          release_order?: number
          topic_id?: string
          updated_at?: string
          weekly_schedule_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "weekly_schedule_topics_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "topics"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "weekly_schedule_topics_weekly_schedule_id_fkey"
            columns: ["weekly_schedule_id"]
            isOneToOne: false
            referencedRelation: "weekly_schedules"
            referencedColumns: ["id"]
          },
        ]
      }
      weekly_schedules: {
        Row: {
          created_at: string
          created_by: string
          id: string
          section_id: string
          status: Database["public"]["Enums"]["schedule_status"]
          updated_at: string
          week_start_date: string
        }
        Insert: {
          created_at?: string
          created_by: string
          id?: string
          section_id: string
          status?: Database["public"]["Enums"]["schedule_status"]
          updated_at?: string
          week_start_date: string
        }
        Update: {
          created_at?: string
          created_by?: string
          id?: string
          section_id?: string
          status?: Database["public"]["Enums"]["schedule_status"]
          updated_at?: string
          week_start_date?: string
        }
        Relationships: [
          {
            foreignKeyName: "weekly_schedules_section_id_fkey"
            columns: ["section_id"]
            isOneToOne: false
            referencedRelation: "sections"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      commit_daily_rating: {
        Args: {
          p_attempt: string
          p_operation: string
          p_rating: Database["public"]["Enums"]["review_rating"]
          p_result: Json
        }
        Returns: string
      }
      confirm_editorial_import: {
        Args: {
          p_filename: string
          p_fingerprint: string
          p_mode: string
          p_rows: Json
        }
        Returns: string
      }
      daily_summary: { Args: { p_section: string }; Returns: Json }
      duplicate_editorial_card: {
        Args: {
          p_expected: string
          p_media: Json
          p_new_id: string
          p_source: string
        }
        Returns: Json
      }
      editorial_normalize: { Args: { value: string }; Returns: string }
      editorial_resolve_taxon: {
        Args: { kind: string; label: string; parent?: string }
        Returns: string
      }
      prepare_daily_rating: { Args: { p_attempt: string }; Returns: Json }
      process_editorial_import: {
        Args: { p_import_id: string; p_limit?: number }
        Returns: Json
      }
      rate_study_item: {
        Args: {
          p_operation: string
          p_rating: Database["public"]["Enums"]["review_rating"]
          p_session: string
        }
        Returns: string
      }
      read_daily_attempt: {
        Args: { p_queue: string; p_reveal?: boolean }
        Returns: Json
      }
      read_study_session: {
        Args: { p_reveal?: boolean; p_session: string }
        Returns: Json
      }
      start_daily_queue: { Args: { p_section: string }; Returns: string }
      start_study_session: {
        Args: { p_section: string; p_topic: string }
        Returns: string
      }
      study_catalog: { Args: { p_section: string }; Returns: Json }
    }
    Enums: {
      app_role: "admin" | "student" | "editor"
      flashcard_status: "draft" | "published" | "archived"
      learning_state: "new" | "learning" | "review" | "relearning"
      media_placement: "question" | "answer" | "comment"
      media_type: "image" | "document"
      review_rating: "again" | "hard" | "good" | "easy"
      schedule_status: "draft" | "published" | "archived"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: ["admin", "student", "editor"],
      flashcard_status: ["draft", "published", "archived"],
      learning_state: ["new", "learning", "review", "relearning"],
      media_placement: ["question", "answer", "comment"],
      media_type: ["image", "document"],
      review_rating: ["again", "hard", "good", "easy"],
      schedule_status: ["draft", "published", "archived"],
    },
  },
} as const
