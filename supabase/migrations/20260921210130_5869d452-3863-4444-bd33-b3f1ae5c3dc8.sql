CREATE POLICY "Students view accessible flashcard media files"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'flashcard-media'
  AND (
    private.can_manage_content(auth.uid())
    OR EXISTS (
      SELECT 1
      FROM public.flashcard_media fm
      JOIN public.flashcards f ON f.id = fm.flashcard_id
      WHERE fm.storage_path = storage.objects.name
        AND fm.is_active
    )
  )
);

CREATE POLICY "Content managers upload flashcard media files"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'flashcard-media'
  AND private.can_manage_content(auth.uid())
);

CREATE POLICY "Content managers update flashcard media files"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'flashcard-media'
  AND private.can_manage_content(auth.uid())
)
WITH CHECK (
  bucket_id = 'flashcard-media'
  AND private.can_manage_content(auth.uid())
);

CREATE POLICY "Content managers delete flashcard media files"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'flashcard-media'
  AND private.can_manage_content(auth.uid())
);